## Context

The app currently uses a native Android `ContentObserver` registered at runtime to detect calendar changes. This observer lives in the app process — when Android kills the process (memory pressure, battery optimization), the observer dies. A periodic `WorkManager` task (`ObserverRegistrationWorker`, 15-min interval) re-registers it, but there is a gap of up to 15 minutes where calendar changes are missed. The periodic fallback sync (also minimum 15 min) catches these eventually, but the combined worst-case latency is ~30 minutes.

Google's own Calendar app uses `JobService` with `TriggerContentUri` to achieve the same goal — these survive process death because the `JobScheduler` (a system service) monitors the content URI independently.

## Goals / Non-Goals

**Goals:**
- Detect calendar changes within ~5 seconds even when the app process is dead
- Eliminate the need for periodic observer re-registration
- Keep the Flutter/Dart side unchanged (same WorkManager callbacks)

**Non-Goals:**
- Changing how background sync runs (same WorkManager task, same sync engine)
- Changing how notifications are displayed
- Supporting Android API levels below 24 (already the minSdk)

## Decisions

### Decision 1: Replace ContentObserver with JobService + TriggerContentUri

**Chosen:** A `JobService` subclass registered in `AndroidManifest.xml` with `android:permission="android.permission.READ_CALENDAR"` that declares a `TriggerContentUri` on `CalendarContract.Events.CONTENT_URI`.

**Rationale:**
- `JobService` with content triggers survives process death — the `JobScheduler` system service monitors the URI
- No lifecycle management needed — no onboarding/reregistration dance
- Google Calendar uses this exact pattern (`CalendarProviderObserverJobService`)
- The `FlutterEngineHolder` indirection is eliminated — the JobService directly enqueues a one-off WorkManager task

**Alternative considered:** Keep `ContentObserver` but register it from a foreground service.
- Rejected: Foreground services require a persistent notification, battery drain, and complex lifecycle management. Worse UX for a calendar sync app.

### Decision 2: JobService directly schedules WorkManager one-off, not MethodChannel

**Chosen:** The `JobService.onStartJob()` directly enqueues a `OneTimeWorkRequest` to `WorkManager` with the `calendar_sync_reactive` task name.

**Rationale:**
- No `FlutterEngine` or `BinaryMessenger` needed — the JobService runs in its own short-lived process context
- The WorkManager task already handles permission checks, settings validation, and sync execution
- Eliminates the `MethodChannel` indirection that currently requires the Flutter engine to be alive

**Alternative considered:** Keep Flutter MethodChannel but create the engine in the JobService.
- Rejected: Starting a Flutter engine from a JobService is heavy (~500ms+), and the engine would be killed when the service stops.

### Decision 3: Remove ObserverRegistrationWorker, keep sync notification in Flutter path

**Chosen:** Remove `ObserverRegistrationWorker.kt` entirely. The `showPendingNotification()` call moves to the Dart sync callback in `sync_task.dart`, which already writes `pending_sync_notification` to SharedPreferences. The notification is shown by a new lightweight Android component that monitors the preference key, or we keep it in the existing observer path.

Actually, looking more carefully: the `CalendarContentObserver` already calls `showPendingNotification()` after a 10s delay. We'll move this to the Dart sync callback's WorkManager path. The `sync_task.dart` already writes to `SharedPreferences` — we'll add a line that triggers notification display directly from Dart (or keep a minimal native notification helper).

**Rationale:** The observer registration work is no longer needed. Notification logic consolidates in the sync execution path.

## Risks / Trade-offs

- **[Risk] JobService timeout**: `onStartJob()` has ~10 seconds to complete before the system kills it. The sync itself runs in WorkManager, so this is fine — we only enqueue work, not execute sync inline. → **Mitigation**: Keep `onStartJob()` lightweight (just enqueue + return false for one-shot).
- **[Risk] Rapid-fire calendar changes**: Multiple changes in quick succession could cause parallel sync runs. → **Mitigation**: Use `ExistingWorkPolicy.REPLACE` on the one-off WorkManager task (already the case) and add a 5s `triggerContentUpdateDelay` in the JobInfo.
- **[Trade-off] No more method channel fallback**: Previously, the method channel allowed direct Flutter-side handling. → **Mitigation**: This path was only ever used to schedule WorkManager anyway; no loss of functionality.

## Why

The current `CalendarContentObserver` is registered in-process via `ContentResolver.registerContentObserver()` in `MainActivity.onCreate()`. When Android kills the app process (memory pressure, battery optimization, or the user swiping the app away), the observer dies with it. It is only re-registered by `ObserverRegistrationWorker`, which runs on a **15-minute periodic WorkManager schedule**. During the gap between process death and re-registration, any calendar changes on the source calendar are missed — relying entirely on the periodic fallback sync (also minimum 15 min) to catch them. This means up to 30 minutes of delay before a background sync catches a change.

## What Changes

- Replace in-process `ContentObserver` (`CalendarContentObserver.kt`) with a `JobService` that uses `TriggerContentUri` on `CalendarContract.Events.CONTENT_URI`
- Remove the `FlutterEngineHolder` indirection for observer-to-Flutter communication
- The JobService directly schedules a WorkManager one-off task when calendar content changes
- Remove `ObserverRegistrationWorker` — no longer needed since JobService is managed by the system
- Update `MainActivity.kt` to remove ContentObserver registration and `ObserverRegistrationWorker` scheduling
- The notification display for sync results moves entirely to the WorkManager callback path in Flutter

## Capabilities

### New Capabilities

- `persistent-observer`: A JobService-based calendar change detector that survives process death and fires within 5 seconds of any calendar content change, without needing periodic re-registration.

### Modified Capabilities

- `background-sync`: The "React to calendar changes via ContentObserver" requirement changes to use JobService + content triggers instead of ContentObserver. The observer is now system-managed and does not require periodic re-registration.

## Impact

- **Kotlin files affected**: `CalendarContentObserver.kt` (replaced), `ObserverRegistrationWorker.kt` (removed), `MainActivity.kt` (simplified)
- **AndroidManifest.xml**: New `JobService` declaration added, `ObserverRegistrationWorker` removed if declared
- **No Dart changes** — the Flutter-side `Workmanager().registerPeriodicTask()` and `registerOneOffTask()` remain unchanged
- **WorkManager DB**: The `observer_registration` periodic work is cancelled and no longer scheduled

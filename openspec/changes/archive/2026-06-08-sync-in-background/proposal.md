## Why

The app currently requires manual interaction to sync. Calendar events change throughout the day — the app should react automatically. More importantly, when events are **deleted** from the source calendar, corresponding events in the target calendar should also be removed. No existing mechanism handles this.

## What Changes

- Replace time-based periodic polling with **reactive sync** via Android ContentObserver — sync fires within seconds of a calendar change, not minutes later
- Add native Kotlin `ContentObserver` that watches `CalendarContract.Events.CONTENT_URI` and triggers the Flutter sync callback via the `workmanager` plugin's existing `BackgroundWorker`
- Add **delete propagation**: when a source event is removed, the corresponding target event is deleted and the mapping record is cleaned up
- Keep a periodic fallback task (every 6 hours) as a safety net for missed triggers
- Add a `sync_interval_minutes` setting (applies to the fallback only; 0 disables all background sync)
- The hybrid architecture maximizes responsiveness while maintaining reliability

## Capabilities

### New Capabilities

- `background-sync`: Register a native Android ContentObserver that triggers sync reactively when the source calendar changes, plus a periodic fallback. The sync cycle now handles event creation and deletion. Persists across app restarts and device reboots.

### Modified Capabilities

- `app-settings`: Add a new `sync_interval_minutes` setting with a default value (60 min, 0 = disabled). Applies to the fallback periodic task.
- `event-sync`: The sync cycle now detects and propagates deletions — when a previously-synced source event is absent, the target event is removed and the mapping cleaned up.

## Impact

- New dependency: `workmanager` Flutter package
- New native file: `android/.../CalendarSyncWorker.kt` (ContentObserver + WorkRequest creation)
- Modified files: `lib/settings/settings_service.dart` (new setting), `lib/sync/sync_engine.dart` (delete handling), `lib/main.dart` (interval UI)
- New file: `lib/background/sync_task.dart` (callbackDispatcher entrypoint)

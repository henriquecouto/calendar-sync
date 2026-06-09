## Why

The app currently shows only a single transient status message after each manual sync ("Synced: N, Deleted: N, ..."). There is no persistent history of sync results. Users have no way to know when the last background sync occurred, what it did, or whether recent changes were picked up. This is especially important now that background sync is fully reactive and reliable — users need confidence it's working without opening the app multiple times.

## What Changes

- A dedicated sync status screen accessible from the home page
- Display the N most recent sync results (timestamp, event counts, errors)
- Persist sync results to SQLite (new `sync_status` table in `calendar_sync.db`)
- The background `callbackDispatcher` appends a timestamped entry to SQLite on every sync
- Manual sync also writes a result entry
- Notification simplified to show "Syncing..." progress, then dismissed on completion — users see results in the history screen instead

## Capabilities

### New Capabilities

- `sync-status-screen`: A screen displaying the last X sync results with timestamps, showing what each sync cycle produced (created, deleted, skipped, errors).

### Modified Capabilities

- `background-sync`: Notification changes from showing sync results to showing progress-only ("Syncing calendars..."), dismissed on completion. Results are visible in the history screen.

## Impact

- **Dart files**: `lib/main.dart` (HomePage — add navigation to status screen), `lib/sync/sync_status_screen.dart` (screen widget), `lib/background/sync_task.dart` (append history to SQLite), `lib/sync/mapping_database.dart` (new table, history methods)
- **Kotlin**: `CalendarSyncJobService.kt` (notification simplified to progress-only, dismissed on completion)
- **No new dependencies**

## 1. Add sync_status table to existing database

- [x] 1.1 In `lib/sync/mapping_database.dart`, bump `version` from 1 to 2 and add `onUpgrade` to create the `sync_status` table with columns: `id` (INTEGER PRIMARY KEY AUTOINCREMENT), `timestamp` (TEXT), `synced` (INTEGER), `deleted` (INTEGER), `skipped` (INTEGER), `errors` (INTEGER)
- [x] 1.2 Add `onCreate` for new installs to create both `sync_mappings` and `sync_status` tables
- [x] 1.3 Add `insertStatus(timestamp, synced, deleted, skipped, errors)` method that inserts a row and deletes the oldest if row count exceeds 20
- [x] 1.4 Add `getStatusHistory(limit: 20)` method that returns rows ordered by id DESC

## 2. Update background sync to write history

- [x] 2.1 In `lib/background/sync_task.dart`, after sync engine completes (or is skipped), call `MappingDatabase().insertStatus()` with the result counts (or zeros for skipped syncs)
- [x] 2.2 Keep existing `pending_sync_notification` write for native notification compatibility

## 3. Create sync status screen UI

- [x] 3.1 Create `lib/sync/sync_status_screen.dart` with a `SyncStatusScreen` StatefulWidget that loads history from `MappingDatabase().getStatusHistory()` on init
- [x] 3.2 Each row shows formatted datetime and counts in notification-style text (e.g., "Synced: 2, Deleted: 1, Skipped: 0 | 3 errors")
- [x] 3.3 Show empty state message when history is empty
- [x] 3.4 Add a refresh button (or pull-to-refresh) to reload from database

## 4. Add navigation from home page

- [x] 4.1 In `lib/main.dart`'s `HomePage.build()`, add an `IconButton(Icons.history)` in `AppBar.actions` that navigates to `SyncStatusScreen`

## 5. Update manual sync to write history

- [x] 5.1 In the `_sync()` method of `HomePage`, after the sync engine completes, call `_mappingDb.insertStatus()` with the `SyncResult` counts

## 6. Simplify notification to progress-only

- [x] 6.1 In `CalendarSyncJobService.kt`, replace `showPendingNotification()` with `showProgressNotification()` that shows an ongoing "Syncing calendars..." notification immediately in `onStartJob()`
- [x] 6.2 Replace the 30s delayed handler with `checkAndDismiss()` that reads `pending_sync_notification` from SharedPreferences, cancels the progress notification if the key exists, and clears the key

## 7. Verify

- [x] 6.1 Run `flutter analyze` and fix any issues
- [x] 6.2 Build and test on emulator: manual sync → open status screen → verify entry appears with correct counts and datetime
- [x] 6.3 Test background sync: trigger via calendar insert → open status screen → verify entry appears
- [x] 6.4 Test cap: sync 25+ times → verify only 20 entries remain
- [x] 6.5 Test skipped sync: disable sync toggle → force background sync → verify zero-count entry appears
- [x] 6.6 Test database upgrade: install old version, then install new version, verify existing mappings table is preserved and sync_status table is created

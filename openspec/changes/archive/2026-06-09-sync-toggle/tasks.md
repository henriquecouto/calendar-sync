## 1. Settings Layer

- [x] 1.1 Add `syncEnabled` getter to `SettingsService` returning `bool` (default `true`)
- [x] 1.2 Add `setSyncEnabled(bool)` setter to `SettingsService` persisting to `sync_enabled` key
- [x] 1.3 Add SharedPreferences key constant `syncEnabledKey = 'sync_enabled'`

## 2. UI Toggle

- [x] 2.1 Add a `Switch` (or `SwitchListTile`) widget on the home screen labeled "Sync enabled" between the interval dropdown and the "Sync Now" button
- [x] 2.2 Load initial toggle state from `SettingsService.syncEnabled` in `initState`
- [x] 2.3 Persist toggle changes via `SettingsService.setSyncEnabled()` on Switch change
- [x] 2.4 Disable the "Sync Now" button when `syncEnabled` is `false` (show disabled style + hint text "Sync is disabled")

## 3. Gate Sync Entry Points

- [x] 3.1 In `_sync()` method in `main.dart`, check `syncEnabled` before calling `SyncEngine.runSync()` — exit early if disabled
- [x] 3.2 In the MethodChannel reactive handler in `main.dart`, check `syncEnabled` before enqueueing the one-off task — skip enqueue if disabled
- [x] 3.3 In `sync_task.dart` callbackDispatcher, check `syncEnabled` before calling `SyncEngine.runSync()` — exit early if disabled

## 4. Verification

- [x] 4.1 Run `flutter analyze` to confirm no project-level issues
- [x] 4.2 Run `flutter test` to confirm existing tests pass
- [x] 4.3 Manually verify: toggle off → "Sync Now" button disabled, toggle on → button re-enabled

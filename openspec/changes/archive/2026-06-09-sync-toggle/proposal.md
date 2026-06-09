## Why

There is currently no way to pause sync without clearing settings or uninstalling the app. Users need a quick toggle to temporarily disable sync (e.g., when on vacation, during device maintenance, or when they want manual-only control). Without this, the only option is to set the interval to 0, which is obscure and not discoverable.

## What Changes

- Add a `syncEnabled` boolean setting persisted in SharedPreferences (default: `true`)
- Add a Switch widget to the home screen labeled "Sync enabled" that toggles the setting
- When sync is disabled, the "Sync Now" button is disabled and shows a hint
- When sync is disabled, background sync triggers (periodic and reactive) exit immediately without syncing
- When sync is re-enabled, all triggers resume normally — no automatic sync is fired on re-enable
- The ContentObserver continues to run regardless (it's lightweight), but the reactive sync callback checks the toggle before executing

## Capabilities

### Modified Capabilities

- `app-settings`: Add `syncEnabled` as a fifth persisted setting with default `true`
- `background-sync`: Background sync callbacks SHALL check `syncEnabled` and exit immediately when disabled
- `event-sync`: The sync engine entry points (manual, reactive, periodic) SHALL gate execution on `syncEnabled`

## Impact

- **SettingsService**: New `syncEnabled` getter/setter, new SharedPreferences key `sync_enabled`
- **main.dart**: New Switch widget, gating logic in `_sync()`, gating in the MethodChannel reactive handler
- **sync_task.dart**: Gating check before calling `SyncEngine.runSync()`
- **UI**: "Sync Now" button disabled state, helper text when toggle is off
- **No new dependencies** — uses existing SharedPreferences

## Why

Users are currently forced to provide a custom "Sync Event Name" for every profile, which replaces all source event titles in the target calendar. Many users want to preserve the original event names instead (e.g., "Doctor Appointment" stays "Doctor Appointment"), as reported in issue #30.

## What Changes

- The "Sync Event Name" field becomes optional — leaving it empty means "keep the original source event title"
- The sync engine uses the original source title as the target event title when `eventName` is empty
- The description format remains unchanged (source title + sync marker), preserving loop-detection and change-detection behavior
- Sync guards (dashboard, background) no longer skip profiles with empty `eventName` — empty now has a valid meaning

## Capabilities

### Modified Capabilities

- `sync-profiles`: The `eventName` field is no longer required. An empty `eventName` means the target event retains the source event's original title. Validation, sync guards, and profile card display adapt accordingly.
- `event-sync`: The "Create synced event with user-provided name" requirement is extended — when `eventName` is empty, the target event title SHALL be the source event's original title.

## Impact

- Modified files: `lib/settings/profile_service.dart` (model — no new fields, just validation context), `lib/sync/sync_engine.dart` (title selection: `eventName.isEmpty ? event.title : eventName`), `lib/screens/profile_config_screen.dart` (relax validation, add helper text), `lib/widgets/profile_card.dart` (display "Original titles" when empty), `lib/screens/dashboard_screen.dart` (guard), `lib/background/sync_task.dart` (guard)
- No DB migration needed — `event_name` already defaults to `''`
- No new dependencies

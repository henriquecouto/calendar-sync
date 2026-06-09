## Why

The sync engine currently handles only creation and deletion of synced events. When a source event's time or title is modified after it was already synced, the target calendar retains the old data. Users who adjust meeting times or rename events must manually update both calendars, undermining the value of automatic sync.

## What Changes

- When a source event already has a mapping (already synced), compare its current `start`, `end`, and `title` with the target event
- If any differ, update the target event to reflect the source changes
- The target event keeps the configured `syncEventName` as its title; the source event's `title` is stored in the target event's `description` (existing behavior, now updated on change too)
- Track updated events separately in `SyncResult` (new `updated` field)

## Capabilities

### New Capabilities

None — this is a modification to existing sync behavior, not a new capability.

### Modified Capabilities

- `event-sync`: The sync engine now detects and propagates changes to already-synced events (title, start time, end time). The `SyncResult` gains an `updated` field.

## Impact

- **Dart files**: `lib/sync/sync_engine.dart` (new update logic, new `updated` field in `SyncResult`), `lib/main.dart` (display `updated` count in status), `lib/background/sync_task.dart` (log updated count to history)
- **No native/Kotlin changes**
- **No new dependencies**

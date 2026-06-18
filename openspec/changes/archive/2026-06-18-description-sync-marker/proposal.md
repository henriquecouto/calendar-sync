## Why

Outlook and other Exchange ActiveSync calendar providers reassign `eventId` values when they re-sync events to the server and back. This breaks loop detection in bidirectional sync, because `sync_created_events` stores stale `eventId` values. The app needs a way to identify its own events that survives provider re-sync.

## What Changes

- When creating a target event, append a structured sync marker to the event description
- Loop detection (`isEventCreatedBySync`) checks the description for the marker instead of (or in addition to) the `sync_created_events` table
- The marker format embeds the original event name and source event ID for traceability
- Update event classification to handle the marker when comparing titles for change detection

## Capabilities

### New Capabilities

- (none)

### Modified Capabilities

- `event-sync`: REQUIREMENT "Record sync mappings" — creation flow must embed a sync marker in the target event's description. REQUIREMENT "Skip events created by sync" — detection must check the description marker as the primary mechanism.

## Impact

- `lib/sync/sync_engine.dart`: modify `_execute` create/update to append marker; modify `_classifySingle` to check marker
- `lib/sync/mapping_database.dart`: may simplify `isEventCreatedBySync` usage (marker replaces table lookup as primary check)
- `test/sync_engine_test.dart`: update test assertions for description format and marker-based skip

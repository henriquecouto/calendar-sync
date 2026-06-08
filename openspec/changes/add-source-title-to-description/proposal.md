## Why

When an event is synced to the target calendar, it currently uses the user-provided name as the title. The original source event's title is lost. Users need to know what the original event was (e.g., "Doctor Appointment") when looking at the target calendar, so the source title should be preserved as the target event's description.

## What Changes

- Synced target events now include the source event's original title as their description
- `CalendarService.createEvent()` gains an optional `description` parameter
- `SyncEngine.runSync()` passes the source event's title as the description when creating target events

## Capabilities

### Modified Capabilities

- `event-sync`: The "Create synced event with user-provided name" requirement now includes the source event title as the target event description.

## Impact

- Modified files: `lib/calendar/calendar_service.dart` (new `description` parameter), `lib/sync/sync_engine.dart` (passes source title as description)
- No new dependencies

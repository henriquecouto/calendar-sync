## Why

All-day events from the source calendar lose their all-day status when synced to the target calendar, appearing as timed events spanning midnight-to-midnight instead. This makes the target calendar cluttered and misrepresents the source events.

## What Changes

- Propagate the `allDay` flag from source events to synced target events
- Include `allDay` in change detection when comparing source and target events for updates
- Extend `CalendarService.createEvent` to accept and pass through the `allDay` flag
- Adjust the cleanup logic for orphan mappings to handle target all-day events (which may have null end times in some calendar providers)

## Capabilities

### New Capabilities

<!-- (none) -->

### Modified Capabilities

- `event-sync`: All-day events SHALL retain their all-day status when synced; change detection SHALL consider the `allDay` flag when deciding whether to update a target event.

## Impact

- `lib/calendar/calendar_service.dart` — `createEvent` signature gains an `allDay` parameter
- `lib/sync/sync_engine.dart` — `_classify` compares `allDay` flag; `ToCreateEntry` propagates `allDay`; `_execute` passes `allDay` to `createEvent`
- `lib/sync/mapping_database.dart` — no changes required

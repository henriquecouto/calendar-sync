## Why

When a source calendar contains a recurring event (e.g., weekly meeting), the sync engine lists the generated instances as separate events. Each instance is classified and synced individually, creating N separate non-recurring target events instead of 1 recurring target. Each target event creation modifies the calendar, triggering the ContentObserver which fires a new background sync. This cascades into repeated sync cycles. With bidirectional multi-profile setups, the churn amplifies.

## What Changes

- When a source event is recurring (`isRecurring == true`) and is NOT an instance (`eventId == instanceId`), the target event SHALL be created as recurring by copying the `recurrenceRule` from the source
- Recurring event instances (`eventId != instanceId`) that belong to an already-synced recurring base SHALL be skipped (one target per recurrence series, not per instance)
- `CalendarService.createEvent()` gains optional recurrence parameters
- No DB schema changes needed

## Capabilities

### Modified Capabilities

- `event-sync`: The sync engine SHALL detect recurring source events, skip their instances, and create a single recurring target event with the source's recurrence rule

## Impact

- **Sync engine**: `_classify` — skip instances of already-synced recurring events; `_execute` create/update — pass recurrence fields to CalendarService
- **Calendar service**: `createEvent` — add optional `RecurrenceRule? recurrenceRule` parameter

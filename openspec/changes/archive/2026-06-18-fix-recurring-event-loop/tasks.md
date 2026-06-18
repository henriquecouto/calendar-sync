## 1. CalendarService Recurrence Support

- [x] 1.1 Add optional `RecurrenceRule? recurrenceRule` parameter to `CalendarService.createEvent()`
- [x] 1.2 Pass `recurrenceRule` through to `device_calendar_plus` plugin's `createEvent` call

## 2. Sync Engine Recurrence Handling

- [x] 2.1 In `_classify()`, skip instances: when `eventId != instanceId`, skip the event (instances are never synced; the base recurring event handles the sync)
- [x] 2.2 In `_execute()` create path, when source event is recurring base (`isRecurring && eventId == instanceId` && `recurrenceRule != null`), pass `recurrenceRule` to `calendarService.createEvent()`
- [x] 2.3 In `_execute()` update path, when replacing a target recurring event, pass updated `recurrenceRule` from source

## 3. Tests & Cleanup

- [x] 3.1 Add test: recurring base event creates recurring target with RRULE
- [x] 3.2 Add test: instance of already-mapped recurring event is skipped
- [x] 3.3 Add test: 5 instances + 1 base → only 1 target created (the base)
- [x] 3.4 Remove debug logs added during investigation
- [x] 3.5 Run `flutter analyze` and `flutter test`

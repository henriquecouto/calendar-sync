## 1. CalendarService — accept allDay parameter

- [x] 1.1 Add optional `bool? allDay` parameter to `CalendarService.createEvent`
- [x] 1.2 Set `event.allDay` on the `Event` object when the parameter is non-null

## 2. Sync engine — propagate allDay in data model

- [x] 2.1 Add `bool? projectedAllDay` field to `ToCreateEntry`
- [x] 2.2 Pass `event.allDay` when constructing `ToCreateEntry` in `_classify`
- [x] 2.3 Pass `entry.projectedAllDay` to `_calendarService.createEvent` in `_execute` (create path)
- [x] 2.4 Pass `sourceEvent.allDay` to `_calendarService.createEvent` in `_execute` (update path)

## 3. Sync engine — include allDay in change detection

- [x] 3.1 Add `allDayChanged` comparison in `_classify` for already-synced events
- [x] 3.2 Include `allDayChanged` in the condition that decides whether to skip or update

## 4. Sync engine — relax null-end-time guard for all-day events

- [x] 4.1 In orphan-mapping cleanup loop: skip the `targetEvent.end == null → delete mapping` guard when `targetEvent.allDay == true`
- [x] 4.2 In already-synced change detection: skip null start/end guard when the target event is all-day; re-create the target event instead

## 5. Sync engine — use timed events (allDay=false) with local timezone for all-day source events

- [x] 5.1 In `_classify`: for all-day source events, set `allDay=false`, `start=local midnight`, `end=local midnight + 1d` (single-day) or `end=last day local midnight + 1d` (multi-day)
- [x] 5.2 In `_execute` update path: same logic

## 6. Sync engine — skip allDay comparison in change detection

- [x] 6.1 Remove `allDayChanged` from the skip condition (source.allDay=true always differs from target.allDay=false)

## 8. Unit tests for all-day sync behavior

- [x] 8.1 Single-day all-day source: target has allDay=false, start=midnight local, end=start+1d
- [x] 8.2 Multi-day all-day source: target has allDay=false, end=last_day_midnight+1d
- [x] 8.3 All-day change detection: skip when dates match, update when start date changes
- [x] 8.4 Timed source: start/end copied as-is (regression)

## 9. Verification

- [x] 9.1 Run `flutter analyze` and fix any issues
- [x] 9.2 Run `flutter test` and fix any test failures
- [x] 9.3 Manually verify all-day events sync correctly — single-day and multi-day

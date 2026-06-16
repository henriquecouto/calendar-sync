## 1. Dependencies

- [x] 1.1 Replace `device_calendar: ^4.3.3` with `device_calendar_plus: 0.6.0` in pubspec.yaml
- [x] 1.2 Remove `timezone: ^0.9.4` from dev_dependencies in pubspec.yaml
- [x] 1.3 Run `flutter pub get` and verify resolution succeeds
- [x] 1.4 Run `flutter pub outdated` and confirm no more blocked transitive updates beyond `device_calendar_plus`

## 2. Calendar Service

- [x] 2.1 Replace `import 'package:device_calendar/device_calendar.dart'` with `import 'package:device_calendar_plus/device_calendar_plus.dart'`
- [x] 2.2 Replace `DeviceCalendarPlugin()` with `DeviceCalendar.instance` singleton
- [x] 2.3 Rewrite `listCalendars()`: `retrieveCalendars()` → `listCalendars()`, remove `Result` unwrapping, add try/catch
- [x] 2.4 Rewrite `listEvents(calendarId)`: `retrieveEvents(calId, params)` → `listEvents(start, end, calendarIds: [calId])`, use native `DateTime.now()` instead of `TZDateTime.now(local)`, remove `RetrieveEventsParams`
- [x] 2.5 Rewrite `getEvent(calendarId, eventId)`: `retrieveEvents(calId, params)` → `getEvent(eventId)`, remove calendarId parameter, remove `RetrieveEventsParams`
- [x] 2.6 Rewrite `createEvent(...)`: remove `Event(calendarId, ...)` constructor, use `createEvent(calendarId:, title:, startDate:, endDate:, description:?, isAllDay:?)` with named parameters, native `DateTime` instead of `TZDateTime`
- [x] 2.7 Rewrite `deleteEvent(calendarId, eventId)`: `deleteEvent(calId, eventId)` → `deleteEvent(eventId: eventId)`, remove calendarId parameter
- [x] 2.8 Add `import 'package:device_calendar_plus/device_calendar_plus.dart'` for `DeviceCalendarException` in error handling

## 3. Sync Engine

- [x] 3.1 Replace `import 'package:device_calendar/device_calendar.dart'` with `import 'package:device_calendar_plus/device_calendar_plus.dart'`
- [x] 3.2 Remove all `TZDateTime` usage: replace `TZDateTime.now(local)` with `DateTime.now()`, replace `TZDateTime.utc(...)` with `DateTime.utc(...)`, remove `.timeZoneOffset` logic
- [x] 3.3 Update `ToCreateEntry` and `ToUpdateEntry` types: `TZDateTime` fields → `DateTime` fields, `Event` → `CalendarEvent`
- [x] 3.4 Update `_localMidnight` helper: replace `TZDateTime` return type with `DateTime`, adjust offset logic if needed
- [x] 3.5 Update `_projectEnd` helper: replace `TZDateTime` parameter/return with `DateTime`
- [x] 3.6 Update event field access in `_classify`: `event.eventId` → stays, `event.title` → stays, `event.start` → `event.startDate`, `event.end` → `event.endDate`, `event.allDay` → `event.isAllDay`, `event.description` → stays
- [x] 3.7 Update `_classify` orphan-mapping check: `targetEvent.end` → `targetEvent.endDate`, `targetEvent.start` → `targetEvent.startDate`, `targetEvent.allDay` → `targetEvent.isAllDay`, threshold comparison uses plain `DateTime`
- [x] 3.8 Update `_classify` time-change detection: replace `.millisecondsSinceEpoch` comparisons on `TZDateTime` with same on `DateTime`, adapt all-day comparison to use `startDate`/`endDate`
- [x] 3.9 Update `_classify` title-change check: `event.title != targetEvent.description` stays same
- [x] 3.10 Update `_execute` create: remove `allDay` projection (passed as `isAllDay:` boolean to `createEvent`)
- [x] 3.11 Update `_execute` delete: remove `calendarId` parameter from `deleteEvent` call
- [x] 3.12 Update `_execute` update (delete+recreate): remove `calendarId` from both delete and create calls
- [x] 3.13 Update `syncedAt` timestamp: replace `TZDateTime.now(local).toString()` with `DateTime.now().toIso8601String()`
- [x] 3.14 Ensure `SyncEngine.runDryRun()` calls updated `_classify` correctly

## 4. Permission Service

- [x] 4.1 Add `import 'package:device_calendar_plus/device_calendar_plus.dart'` to permission_service.dart
- [x] 4.2 Update `areCalendarPermissionsGranted`: use `DeviceCalendar.instance.hasPermissions()` comparing against `CalendarPermissionStatus.granted`
- [x] 4.3 Update `requestCalendarPermissions()`: use `DeviceCalendar.instance.requestPermissions()` mapping to bool
- [x] 4.4 Keep `permission_handler` for notification permissions and `openAppSettings()` (unrelated to calendar plugin)

## 5. Main Entry Point

- [x] 5.1 Remove `import 'package:timezone/timezone.dart'` and `import 'package:timezone/data/latest.dart'`
- [x] 5.2 Remove `initializeTimezones()` call from `main()`

## 6. Tests

- [x] 6.1 Update test imports: replace `device_calendar` with `device_calendar_plus` in all test files
- [x] 6.2 Update mock/test types: `Event` → `CalendarEvent`, `Calendar` → `PlatformCalendar`, `TZDateTime` → `DateTime`
- [x] 6.3 Fix all compilation errors in tests
- [x] 6.4 Run `flutter test` and verify all tests pass
- [x] 6.5 Run `flutter analyze` and verify no warnings or errors

## 7. Verification

- [x] 7.1 Run `flutter build apk --debug` to confirm APK compiles
- [x] 7.2 Manual test on Android device: install APK, grant permissions, run sync cycle, verify events appear in target calendar

## 8. All-Day Half-Open Interval Fix

- [x] 8.1 Remove `_projectEnd` helper — obsoleted by half-open intervals in `device_calendar_plus`
- [x] 8.2 In `_classify`, replace `_projectEnd(event)` with `DateTime(event.endDate.year, event.endDate.month, event.endDate.day)` for projectedEnd
- [x] 8.3 In `_classify`, change all-day time-change detection: `srcDays + 1 != tgtDays` → `srcDays != tgtDays`
- [x] 8.4 In `_execute` create path, replace `_projectEnd(event)` with `DateTime(event.endDate.year, event.endDate.month, event.endDate.day)` for projectedEnd
- [x] 8.5 In `_execute` update path, replace `_projectEnd(event)` with `DateTime(event.endDate.year, event.endDate.month, event.endDate.day)` for updateEnd
- [x] 8.6 Run `flutter test` and verify all tests still pass
- [x] 8.7 Run `flutter analyze` and verify no warnings

## 1. Extend CalendarService for event updates

- [x] 1.1 In `lib/calendar/calendar_service.dart`, add optional `eventId` parameter to `createEvent()` — when provided, the plugin's `createOrUpdateEvent` updates the existing event instead of creating a new one
- [x] 1.2 Add `getEvent(calendarId, eventId)` method to fetch a single target event for comparison

## 2. Add update logic to SyncEngine

- [x] 2.1 Add `updated` field to `SyncResult` class (similar to `synced`, `deleted`, `skipped`, `errors`)
- [x] 2.2 In `runSync()`, for already-synced events, fetch the target event and compare its `start`, `end`, and `description` against the source event's values
- [x] 2.3 If any field differs, call `_calendarService.createEvent()` with the target event's ID to update it, add the event ID to `updated`
- [x] 2.4 If no fields differ, add to `skipped` as before

## 3. Update status display and history

- [x] 3.1 In `lib/main.dart`'s `_sync()` method, include `updated` count in the status text
- [x] 3.2 In `lib/background/sync_task.dart`, pass `updated` count to `_logStatus()` and include it in the SQLite history row

## 4. Verify

- [x] 4.1 Run `flutter analyze` and fix any issues
- [x] 4.2 Build and test on emulator: create event, sync, modify event time in source calendar, sync again → verify target event time is updated
- [x] 4.3 Test title change: modify source event title, sync → verify target event description is updated
- [x] 4.4 Test unchanged event: sync after no changes → verify event is skipped (not updated)

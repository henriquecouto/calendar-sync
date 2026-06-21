## 1. Platform channel — replace with standard delete

- [x] 1.1 Replace `softDeleteEvent` handler body with a single `ContentResolver.delete(Events.CONTENT_URI, "_id = ?", [eventId])` call — no `CALLER_IS_SYNCADAPTER`, no account query params
- [x] 1.2 Change method name from `softDeleteEvent` to `deleteEvent` and accept `eventId` as `String` (not `Long`)
- [x] 1.3 Remove `buildSyncAdapterUri()` method entirely
- [x] 1.4 Remove `readCalendarAccount()` method entirely
- [x] 1.5 Remove the `ContentResolver.requestSync()` + `AccountManager.getAccounts()` loop
- [x] 1.6 Remove the `ContentValues(DELETED=1, DIRTY=1)` and `ContentResolver.update()` call
- [x] 1.7 Return `result.success(deletedRows > 0)` — `true` if 1+ rows affected, `false` otherwise

## 2. CalendarService — simplify delete API

- [x] 2.1 Change `deleteEvent` signature to `Future<CalendarDeleteResult> deleteEvent(String eventId)` — no `calendarId` parameter
- [x] 2.2 Change platform channel invoke from `softDeleteEvent` to `deleteEvent`, passing only `eventId`
- [x] 2.3 Remove the `int.tryParse(eventId)` guard — all eventIds go through the platform channel as strings
- [x] 2.4 Remove the `device_calendar_plus` hard-delete fallback (`_plugin.deleteEvent`)
- [x] 2.5 Simplify `CalendarDeleteResult` to `const CalendarDeleteResult({required this.success})` — remove `usedSoftDelete` field
- [x] 2.6 Return `CalendarDeleteResult(success: false)` on platform channel exception

## 3. Sync engine — remove re-check, fix update-path delete

- [x] 3.1 Remove the `if (!deleteResult.usedSoftDelete)` block (5-second wait + `stillExists` re-check)
- [x] 3.2 For update path: check the delete result and log error if failed — but continue (replacement event already created, old event becomes orphan for next cycle)
- [x] 3.3 Ensure all callers that checked `usedSoftDelete` now only check `success`

## 4. Verify

- [x] 4.1 Run `flutter analyze` and fix any issues
- [x] 4.2 Run `flutter test` and ensure all existing tests pass

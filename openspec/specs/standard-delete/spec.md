# Standard Delete

## Purpose

Use standard Android `ContentResolver.delete()` on plain `Events.CONTENT_URI` for all event deletions, delegating soft vs hard delete decisions to the Calendar Provider.

## Requirements

### Requirement: Standard ContentResolver delete for all calendars
The platform channel SHALL delete events using `ContentResolver.delete()` on plain `Events.CONTENT_URI` (no `CALLER_IS_SYNCADAPTER`, no account query params). The Android Calendar Provider SHALL automatically determine the correct deletion strategy: for events belonging to synced calendars, the Provider SHALL set `DELETED=1` and `DIRTY=1` to allow sync adapters to propagate the deletion; for events belonging to local calendars, the Provider SHALL physically remove the row.

#### Scenario: Synced calendar event auto-soft-deleted
- **WHEN** `deleteEvent` is called for an event on a DAVdroid calendar
- **THEN** the platform channel calls `ContentResolver.delete(Events.CONTENT_URI, "_id=?", [eventId])`
- **AND** the Calendar Provider sets `DELETED=1` and `DIRTY=1` on the row
- **AND** the sync adapter framework detects the change and propagates the deletion to the server
- **AND** the method returns `true`

#### Scenario: Local calendar event physically removed
- **WHEN** `deleteEvent` is called for an event on a local device calendar
- **THEN** the platform channel calls `ContentResolver.delete(Events.CONTENT_URI, "_id=?", [eventId])`
- **AND** the Calendar Provider physically removes the row from the database
- **AND** the method returns `true`

#### Scenario: Delete non-existent event returns false
- **WHEN** `deleteEvent` is called for an event ID that does not exist
- **THEN** `ContentResolver.delete()` returns 0 rows affected
- **AND** the method returns `false`

#### Scenario: Non-numeric event ID handled correctly
- **WHEN** `deleteEvent` is called with `eventId="abc-123@outlook.com"`
- **THEN** the platform channel passes the string to the `_id` WHERE clause
- **AND** SQLite's type affinity allows the TEXT-to-INTEGER comparison
- **AND** the deletion proceeds normally

### Requirement: No manual sync-adapter URI construction
The platform channel SHALL NOT construct sync-adapter URIs (no `CALLER_IS_SYNCADAPTER` query parameter). The method `buildSyncAdapterUri` and `readCalendarAccount` SHALL be removed. No manual `ContentResolver.requestSync()` calls SHALL be made — the Provider triggers sync propagation automatically.

#### Scenario: No sync-adapter URI used
- **WHEN** any delete is performed
- **THEN** the URI is plain `Events.CONTENT_URI` without any query parameters
- **AND** no `ContentResolver.update()` with DELETED=1 is called
- **AND** no `AccountManager.getAccounts()` or `requestSync` is called

### Requirement: Platform channel receives eventId as String
The platform channel SHALL accept `eventId` as a `String` parameter. The method SHALL NOT require `calendarId` — the Calendar Provider resolves the event's calendar internally.

#### Scenario: eventId passed as String
- **WHEN** Dart calls the platform channel with `{"eventId": "42"}`
- **THEN** the Kotlin handler receives it as `String` and uses it in the `_id` WHERE clause

#### Scenario: No calendarId parameter
- **WHEN** Dart calls the platform channel for deletion
- **THEN** only `eventId` is passed
- **AND** the Calendar Provider resolves the calendar internally from the event's `CALENDAR_ID` column

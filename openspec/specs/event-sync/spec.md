# Event Sync

## Purpose

Detect unsynced events via a local mapping table and create corresponding events in a target calendar using a user-provided name. Also detect and propagate deletions when source events are removed.

## Requirements

### Requirement: Detect already-synced events
The system SHALL query the local mapping table to determine whether a source event (identified by profile ID + source calendar ID + source event ID) has already been synced to a target calendar for a given profile. If already synced, the system SHALL compare the source event's start time, end time, and title with the target event's fields and update the target event if any differ. If the target event's start or end time is null, the system SHALL skip the event. If no fields differ, the event is skipped. When comparing the source event's title against the target event's description, the system SHALL use `contains` (not `startsWith` or exact match) to handle descriptions that may be wrapped in HTML by calendar providers.

#### Scenario: Event is already synced with no changes
- **WHEN** a source event's (profile_id, calendar_id, event_id) pair exists in the mapping table and its start, end, and title match the target event
- **THEN** the system skips that event

#### Scenario: Event is already synced with time change
- **WHEN** a source event's (profile_id, calendar_id, event_id) pair exists in the mapping table and its start or end time differ from the target event
- **THEN** the target event is updated with the new times

#### Scenario: Event is already synced with title change
- **WHEN** a source event's (profile_id, calendar_id, event_id) pair exists in the mapping table and its title is NOT contained anywhere in the target event's description
- **THEN** the target event's description is updated to the new source title

#### Scenario: HTML-wrapped description is recognized as unchanged
- **WHEN** the target event's description is `<html><body>Doctor Appointment<br>---<br>🔃 Automatically created by CalSync</body></html>`
- **AND** the source event's title is `Doctor Appointment`
- **THEN** the system SHALL detect no title change via `contains("Doctor Appointment")`
- **AND** the event SHALL be skipped if no other fields changed

#### Scenario: Event is not yet synced
- **WHEN** a source event's (profile_id, calendar_id, event_id) pair is absent from the mapping table
- **THEN** the system marks it for sync and creates a target event

#### Scenario: Target event has null times
- **WHEN** a source event's (profile_id, calendar_id, event_id) pair exists in the mapping table and the target event's start or end time is null
- **THEN** the system skips the event without crashing

### Requirement: Create synced event with user-provided name
The system SHALL create a target event using the user-configured sync name (not the original event title). The target event SHALL copy the source event's start time and end time. The target event's description SHALL be set to the original source event title followed by a sync marker in the format:

```
<original title>
---
🔃 Automatically created by CalSync
```

If the source event is recurring (`isRecurring == true`), the target event SHALL also be created as recurring, copying the source event's `recurrenceRule`.

#### Scenario: Synced event uses custom name and embeds sync marker
- **WHEN** the user has configured "Busy" as the sync name and a source event titled "Doctor Appointment" appears
- **THEN** the target event has the title "Busy", the same start/end times as the source event
- **AND** the description is:
  ```
  Doctor Appointment
  ---
  🔃 Automatically created by CalSync
  ```

#### Scenario: Recurring source creates recurring target
- **WHEN** the source event has `isRecurring: true`, `eventId: "100"`, `instanceId: "100"`, and `recurrenceRule: "FREQ=WEEKLY;BYDAY=MO"`
- **THEN** the target event is created with the same recurrence rule
- **AND** the description includes the sync marker

#### Scenario: Non-recurring source creates non-recurring target
- **WHEN** the source event has `isRecurring: false`
- **THEN** the target event is created without recurrence fields
- **AND** the description includes the sync marker

### Requirement: Record sync mappings
After successfully creating a target event, the system SHALL insert a row into the mapping table recording (profile_id, source_calendar_id, source_event_id, target_calendar_id, target_event_id, synced_at). If the source event is recurring, the system SHALL also store the `HH:mm` of the source's `startDate` as `canonical_time`.

#### Scenario: Mapping recorded after sync
- **WHEN** a source event is synced for profile "abc-123" and a target event is created with ID "TGT-456"
- **THEN** the mapping table contains a row linking profile "abc-123", source event "SRC-123" (calendar 1) to target event "TGT-456" (calendar 2) with the current timestamp

#### Scenario: Duplicate mapping prevented within same profile
- **WHEN** the same source event is encountered twice for the same profile before the first sync completes
- **THEN** the UNIQUE constraint on (profile_id, source_calendar_id, source_event_id) prevents a duplicate mapping and a second target event is not created

#### Scenario: Same event synced by different profiles is allowed
- **WHEN** a source event "SRC-123" on calendar "CAL-A" is synced by profile "P1" to calendar "CAL-B"
- **AND** the same source event "SRC-123" on calendar "CAL-A" is synced by profile "P2" to calendar "CAL-C"
- **THEN** both profiles SHALL have independent mapping rows in the table without conflict

#### Scenario: Mapping removed on source event deletion
- **WHEN** a source event "SRC-789" with mapping for profile "abc-123" to target event "TGT-012" is deleted from the source calendar
- **THEN** the mapping row is removed after the target event is deleted

### Requirement: Run full sync cycle
The system SHALL execute a sync cycle for a given profile: list source events (from now to now+30d), query mapping table filtered by profile ID and source calendar, for each mapped source event absent from the fetch window check the target event's end time against a 7-day threshold. If the target event's end time is more than 7 days in the past, skip it. If the target event's end time is within 7 days, fetch the source event by ID: if found, re-classify it (update/create path); if not found, delete the target event and remove its mapping. The system SHALL also create target events for unmapped source events, update target events for already-synced source events whose fields changed, and record new mappings with the profile ID. Recurring event instances (`eventId != instanceId`) are fetched via base event ID and never directly classified; the base event is classified once per cycle instead.

#### Scenario: Full sync with new events
- **WHEN** the source calendar has 3 events and none are in the mapping table
- **THEN** the system creates 3 target events with the user-provided name and inserts 3 mapping rows

#### Scenario: Full sync with mixed state
- **WHEN** the source calendar has 5 events and 2 are already mapped
- **THEN** the system creates 3 target events for the unmapped ones and skips 2 if unchanged

#### Scenario: Full sync with deleted source event
- **WHEN** the source calendar previously had 3 events (all synced) and now has only 2
- **THEN** the system deletes the target event for the missing source event, removes its mapping, and leaves the other 2 untouched

#### Scenario: Full sync with updated events
- **WHEN** the source calendar has 3 synced events and 2 had their times changed
- **THEN** the system updates 2 target events with the new times and reports them as updated

#### Scenario: Full sync with additions, deletions, and updates
- **WHEN** the source calendar had 4 synced events and now has 3 (1 deleted, 1 new, 1 modified, 1 unchanged)
- **THEN** the system deletes 1, creates 1, updates 1, and skips 1

#### Scenario: Full sync scoped to correct profile
- **WHEN** profile "P1" syncs from calendar "CAL-A" and profile "P2" syncs from calendar "CAL-A"
- **AND** profile "P1" has existing mappings for events on "CAL-A"
- **THEN** profile "P2" SHALL NOT see profile "P1"'s mappings and SHALL classify its own source events independently

#### Scenario: Full sync with recurring event
- **WHEN** the source calendar has a recurring event "Weekly Standup" (base ID "100", 5 instances in window)
- **THEN** the system creates exactly 1 target recurring event for the base "100"
- **AND** all 5 instances are skipped

#### Scenario: Old past event is ignored
- **WHEN** a synced source event is absent from the fetch window AND its target event's end time is more than 7 days in the past
- **THEN** the system does NOT delete the target event

#### Scenario: Recent past event with source still existing (edited outside window)
- **WHEN** a synced source event is absent from the fetch window AND its target event's end time is within 7 days
- **AND** the source event still exists (found via getEvent by ID) — e.g., it was edited to a past date outside the fetch window
- **THEN** the system re-classifies the source event (updates target if fields changed, skips if unchanged)
- **AND** does NOT delete the target event

#### Scenario: Recent past event with source truly deleted
- **WHEN** a synced source event is absent from the fetch window AND its target event's end time is within 7 days
- **AND** the source event is genuinely gone (getEvent by ID returns null)
- **THEN** the system deletes the target event and removes the mapping

#### Scenario: Orphan mapping with missing target event
- **WHEN** a synced source event is absent from the fetch window AND the target event no longer exists in the target calendar
- **THEN** the system removes the orphan mapping without error

### Requirement: Manual sync gated on sync enabled
The system SHALL disable the "Sync Now" button and prevent manual sync execution when sync is disabled. When sync is re-enabled, the button SHALL become active again but SHALL NOT automatically trigger a sync.

#### Scenario: Sync Now button disabled when sync is off
- **WHEN** sync is disabled
- **THEN** the "Sync Now" button is visually disabled and does not respond to taps

#### Scenario: Sync Now button re-enabled when sync is turned on
- **WHEN** sync is re-enabled
- **THEN** the "Sync Now" button becomes active but no sync is triggered automatically

#### Scenario: Manual sync proceeds when sync is enabled
- **WHEN** the user presses "Sync Now" and sync is enabled
- **THEN** a full sync cycle executes normally

### Requirement: All-day source events create all-day target events
The system SHALL copy all-day source events as all-day target events, preserving the source event's `startDate`, `endDate`, and `isAllDay` flag without date projection or time stripping. The `device_calendar_plus` plugin already uses half-open intervals `[startDate, endDate)` for all-day events, so no conversion is needed.

#### Scenario: Single-day all-day copied as all-day
- **WHEN** the source event is all-day with startDate=2026-06-23, endDate=2026-06-24
- **THEN** the target event is created with `isAllDay: true`, startDate=2026-06-23, endDate=2026-06-24 (same dates, no projection)

#### Scenario: Multi-day all-day copied as all-day
- **WHEN** the source event is all-day with startDate=2026-06-23, endDate=2026-06-26
- **THEN** the target event is created with `isAllDay: true`, startDate=2026-06-23, endDate=2026-06-26

### Requirement: All-day change detection uses uniform timestamp comparison
The system SHALL detect changes in all-day events using the same `millisecondsSinceEpoch` comparison as timed events, without a special branch for all-day duration logic.

#### Scenario: All-day with matching start/end is skipped
- **WHEN** source all-day event has startDate=A, endDate=B
- **AND** target all-day event has startDate=A, endDate=B and description matches
- **THEN** the event is skipped (no change detected)

#### Scenario: All-day with date change is updated
- **WHEN** source all-day event has startDate changed
- **AND** target all-day event still has the old startDate
- **THEN** the event is classified as toUpdate, creating a replacement all-day event with the same dates as the source

### Requirement: No date projection helpers
The sync engine SHALL NOT use `_localMidnight` or `_projectEnd` helpers. All-day event dates SHALL pass through from source to target without modification.

### Requirement: Skip recurring event instances
When a source event is an instance of a recurring event (`eventId != instanceId`), the system SHALL fetch the base recurring event by `eventId` once per sync cycle and classify it instead of the instance (using the instance's start/end times but the base's recurrence rule). When comparing the merged event against an already-synced target, the system SHALL compare only the time-of-day (`HH:mm`) of `startDate` against the stored `canonical_time` in the mapping, ignoring the date component. Title changes and recurrence rule changes are still detected as before.

#### Scenario: Instance of already-synced recurring event is skipped but base is checked
- **WHEN** a recurring base event "100" is already mapped
- **AND** an instance appears with `eventId: "100"` and `instanceId: "100@timestamp"`
- **THEN** the instance is skipped
- **AND** the base event "100" is fetched and classified to detect changes (time/title)

#### Scenario: Instance of unsynced recurring event triggers base sync
- **WHEN** a recurring base event "100" is NOT yet mapped
- **AND** an instance appears with `eventId: "100"` and `instanceId: "100@timestamp"`
- **THEN** the base event "100" is fetched and classified as toCreate using the instance's start/end times and the base's recurrence rule

#### Scenario: Recurring event unchanged across cycles is skipped
- **WHEN** a recurring event "100" is already synced with canonical_time "10:00"
- **AND** in a later cycle the earliest instance has start=2026-06-19 10:00
- **THEN** HH:mm "10:00" matches canonical_time "10:00" → timeChanged is false → event is skipped

#### Scenario: User changes recurring event time detected
- **WHEN** a recurring event "100" is already synced with canonical_time "10:00"
- **AND** the user changes the recurring event start time to 14:00
- **THEN** the next cycle's earliest instance has HH:mm "14:00" → differs from canonical_time "10:00" → timeChanged is true → UPDATE

#### Scenario: Non-recurring event is classified normally
- **WHEN** a source event has `eventId == instanceId`
- **THEN** the system classifies it normally using existing mapping checks

### Requirement: Database schema includes canonical_time
The `sync_mappings` table SHALL include a nullable `canonical_time TEXT` column. This column is set when a target event is created for a recurring source and used for time-of-day comparison during subsequent syncs.

#### Scenario: canonical_time stored for recurring events
- **WHEN** a target is created for a recurring source event with start=10:00
- **THEN** the mapping row stores canonical_time="10:00"

#### Scenario: canonical_time is null for non-recurring events
- **WHEN** a target is created for a non-recurring source event
- **THEN** the mapping row has canonical_time=null

### Requirement: CalendarService supports recurrence parameter
The `CalendarService.createEvent()` method SHALL accept an optional `RecurrenceRule? recurrenceRule` parameter. When provided, it SHALL be passed to the `device_calendar_plus` plugin's `createEvent` call.

#### Scenario: Recurrence rule passed to plugin
- **WHEN** `createEvent` is called with `recurrenceRule: WeeklyRecurrence(daysOfWeek: [DayOfWeek.monday])`
- **THEN** the plugin creates a recurring event with the given recurrence rule

### Requirement: Sync engine accepts profile ID
The sync engine SHALL accept a `profileId` parameter for all sync operations (`runSync`, `runDryRun`). All mapping queries (isEventSynced, listMappingsForCalendar, insertMapping) SHALL include `profileId` as a filter. All status inserts SHALL include `profileId`.

#### Scenario: Sync with profile ID
- **WHEN** `runSync` is called with `profileId: "abc-123"`
- **THEN** all mapping lookups and inserts SHALL include `profileId: "abc-123"` in their WHERE clauses
- **AND** the status entry SHALL include `profile_id: "abc-123"`

#### Scenario: Dry run with profile ID
- **WHEN** `runDryRun` is called with `profileId: "abc-123"`
- **THEN** all mapping lookups SHALL include `profileId: "abc-123"` in their WHERE clauses

### Requirement: Soft-delete target events for sync adapter propagation
The system SHALL delete target events by setting `DELETED=1` and `DIRTY=1` on the Android Calendar Provider event row, using a sync-adapter context URI (`CALLER_IS_SYNCADAPTER=true`) so the Calendar Provider allows writing to the `DIRTY` field. After marking the event, the system SHALL call `ContentResolver.requestSync()` for all device accounts to trigger immediate sync adapter propagation. This ensures sync adapters (e.g., DAVdroid) detect the deletion and push it to the remote server.

The soft-delete operation SHALL be implemented as a native FlutterPlugin (`SoftDeletePlugin`) registered in `GeneratedPluginRegistrant.java` via a Gradle build task, making it available in both foreground and background Flutter engines.

#### Scenario: Target event soft-deleted on source deletion
- **WHEN** a source event is deleted from the source calendar
- **AND** the sync engine detects the orphaned mapping
- **THEN** the target event row is updated with `DELETED=1` and `DIRTY=1` using sync-adapter context URI
- **AND** `ContentResolver.requestSync()` is called for all accounts
- **AND** the mapping is removed from the local database

#### Scenario: Soft-delete works in background sync
- **WHEN** the Workmanager periodic task triggers a sync
- **AND** an orphaned mapping is detected requiring target deletion
- **THEN** the SoftDeletePlugin is available via the background FlutterEngine's GeneratedPluginRegistrant
- **AND** the soft-delete proceeds without falling back to hard-delete

### Requirement: Hard-delete fallback with post-deletion verification
If the soft-delete MethodChannel is unavailable, the system SHALL fall back to the `device_calendar_plus` plugin's hard-delete. After a hard-delete, the system SHALL wait 5 seconds and then call `getEvent` on the target event ID. If the event still exists (the provider restored it), the system SHALL NOT remove the mapping, allowing a retry on the next sync cycle.

#### Scenario: Hard-delete fallback with successful verification
- **WHEN** soft-delete fails and hard-delete is used
- **AND** 5 seconds after deletion, `getEvent` returns null (event is gone)
- **THEN** the mapping is removed

#### Scenario: Hard-delete fallback with event restoration
- **WHEN** soft-delete fails and hard-delete is used
- **AND** 5 seconds after deletion, `getEvent` still returns the event (provider restored it)
- **THEN** the mapping is preserved for retry on the next sync cycle
- **AND** an error is recorded

### Requirement: Skip source events that were created by sync engine
The system SHALL check the description of every source event for the sync marker `"🔃 Automatically created by CalSync"` before classifying it. If the description contains the marker, the system SHALL skip the event to prevent sync loops. The system SHALL also maintain the `sync_created_events` table as a secondary check for cases where the description may be unavailable or truncated. When a target event is deleted (orphan processing, profile deletion, or update replacement), the corresponding row in `sync_created_events` SHALL be removed.

The check order in `_classifySingle` SHALL be:
1. Check description for sync marker → skip if present
2. Check `sync_created_events` table → skip if present (defense-in-depth)
3. Check mapping table → classify as create/update/skip

#### Scenario: Event created by another profile is skipped via description marker
- **WHEN** Profile A creates a target event with description containing "🔃 Automatically created by CalSync"
- **AND** Outlook re-syncs the event, changing its `eventId` from "TGT-100" to "TGT-200"
- **AND** Profile B lists the event in the source calendar with the new `eventId`
- **THEN** Profile B checks the description, finds the marker, and skips it
- **AND** no loop occurs

#### Scenario: User-created event is NOT skipped (no marker)
- **WHEN** the user manually creates "Reunião 10h" in the Work calendar as evt-001
- **AND** the description does not contain the sync marker
- **THEN** the event SHALL be classified normally (create or skip based on mapping)

#### Scenario: Event created by sync with intact eventId is still skipped via description
- **WHEN** `sync_created_events` has `(Work, evt-100)` and the description also contains the marker
- **THEN** the event is skipped by the description check (first priority)

#### Scenario: Marker detection when description is null
- **WHEN** a source event has `description: null`
- **THEN** the system SHALL NOT crash on null description
- **AND** SHALL fall through to the `sync_created_events` table check

#### Scenario: Entry inserted on target event creation
- **WHEN** the sync engine successfully creates a target event evt-200 in calendar "CAL-B"
- **THEN** a row `(CAL-B, evt-200)` SHALL be inserted into `sync_created_events`

#### Scenario: Entry removed on target event deletion
- **WHEN** the sync engine deletes a target event evt-200 during orphan processing
- **THEN** the row `(calendar, evt-200)` SHALL be removed from `sync_created_events`

#### Scenario: Entry replaced on target event update
- **WHEN** the sync engine updates a target event by creating a replacement evt-300 and deleting the old evt-200
- **THEN** the old row `(calendar, evt-200)` SHALL be removed
- **AND** a new row `(calendar, evt-300)` SHALL be inserted

#### Scenario: Full graph sync without loops
- **WHEN** 6 profiles form a complete directed graph between calendars Work1, Work2, and Personal (all bidirectional pairs)
- **AND** a user creates a single event manually in Work1
- **THEN** each profile SHALL sync the event to its target exactly once
- **AND** no profile SHALL create more than one target event for the same logical source event

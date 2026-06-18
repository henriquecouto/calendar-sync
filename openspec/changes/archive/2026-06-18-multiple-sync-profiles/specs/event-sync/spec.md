# event-sync (delta)

## MODIFIED Requirements

### Requirement: Detect already-synced events
The system SHALL query the local mapping table to determine whether a source event (identified by profile ID + source calendar ID + source event ID) has already been synced to a target calendar for a given profile. If already synced, the system SHALL compare the source event's start time, end time, and title with the target event's fields and update the target event if any differ. If the target event's start or end time is null, the system SHALL skip the event. If no fields differ, the event is skipped.

#### Scenario: Event is already synced with no changes
- **WHEN** a source event's (profile_id, calendar_id, event_id) pair exists in the mapping table and its start, end, and title match the target event
- **THEN** the system skips that event

#### Scenario: Event is already synced with time change
- **WHEN** a source event's (profile_id, calendar_id, event_id) pair exists in the mapping table and its start or end time differ from the target event
- **THEN** the target event is updated with the new times

#### Scenario: Event is already synced with title change
- **WHEN** a source event's (profile_id, calendar_id, event_id) pair exists in the mapping table and its title differs from the target event's description
- **THEN** the target event's description is updated to the new source title

#### Scenario: Event is not yet synced
- **WHEN** a source event's (profile_id, calendar_id, event_id) pair is absent from the mapping table
- **THEN** the system marks it for sync and creates a target event

#### Scenario: Target event has null times
- **WHEN** a source event's (profile_id, calendar_id, event_id) pair exists in the mapping table and the target event's start or end time is null
- **THEN** the system skips the event without crashing

### Requirement: Record sync mappings
After successfully creating a target event, the system SHALL insert a row into the mapping table recording (profile_id, source_calendar_id, source_event_id, target_calendar_id, target_event_id, synced_at). When a source event is deleted, the system SHALL remove the corresponding mapping row after deleting the target event.

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
The system SHALL execute a sync cycle for a given profile: list source events (from now to now+30d), query mapping table filtered by profile ID and source calendar, for each mapped source event absent from the fetch window check the target event's end time against a 7-day threshold (skip if older, confirm via source-by-ID if recent), create target events for unmapped source events, update target events for already-mapped source events whose fields changed, and record new mappings with the profile ID.

#### Scenario: Full sync with new events
- **WHEN** the source calendar for profile "P1" has 3 events and none are in the mapping table for profile "P1"
- **THEN** the system creates 3 target events with the profile's event name and inserts 3 mapping rows with profile ID "P1"

#### Scenario: Full sync with mixed state
- **WHEN** the source calendar for profile "P1" has 5 events and 2 are already mapped for profile "P1"
- **THEN** the system creates 3 target events for the unmapped ones and skips 2 if unchanged

#### Scenario: Full sync with deleted source event
- **WHEN** the source calendar for profile "P1" previously had 3 events (all synced) and now has only 2
- **THEN** the system deletes the target event for the missing source event, removes its mapping, and leaves the other 2 untouched

#### Scenario: Full sync scoped to correct profile
- **WHEN** profile "P1" syncs from calendar "CAL-A" and profile "P2" syncs from calendar "CAL-A"
- **AND** profile "P1" has existing mappings for events on "CAL-A"
- **THEN** profile "P2" SHALL NOT see profile "P1"'s mappings and SHALL classify its own source events independently

## ADDED Requirements

### Requirement: Sync engine accepts profile ID
The sync engine SHALL accept a `profileId` parameter for all sync operations (`runSync`, `runDryRun`). All mapping queries (isEventSynced, listMappingsForCalendar, insertMapping) SHALL include `profileId` as a filter. All status inserts SHALL include `profileId`.

#### Scenario: Sync with profile ID
- **WHEN** `runSync` is called with `profileId: "abc-123"`
- **THEN** all mapping lookups and inserts SHALL include `profileId: "abc-123"` in their WHERE clauses
- **AND** the status entry SHALL include `profile_id: "abc-123"`

#### Scenario: Dry run with profile ID
- **WHEN** `runDryRun` is called with `profileId: "abc-123"`
- **THEN** all mapping lookups SHALL include `profileId: "abc-123"` in their WHERE clauses

### Requirement: Skip source events that were created by sync engine
The system SHALL maintain a global `sync_created_events` table recording `(calendar_id, event_id)` for every target event created by any sync profile. Before classifying any source event as new, the system SHALL check this table. If the source event was created by the sync engine (any profile), the system SHALL skip it to prevent sync loops. When a target event is deleted (orphan processing, profile deletion, or update replacement), the corresponding row in `sync_created_events` SHALL be removed.

#### Scenario: Event created by another profile is skipped
- **WHEN** Profile A (Work→Personal) creates "Busy" in the Personal calendar as evt-100
- **AND** `sync_created_events` contains `(Personal, evt-100)`
- **AND** Profile B (Personal→Work) runs a sync cycle scanning the Personal calendar
- **THEN** Profile B SHALL query `sync_created_events` for evt-100
- **AND** finding the entry, Profile B SHALL skip evt-100 without creating a new event in Work

#### Scenario: User-created event is NOT skipped
- **WHEN** the user manually creates "Reunião 10h" in the Work calendar as evt-001
- **AND** `sync_created_events` does NOT contain `(Work, evt-001)`
- **AND** a profile syncs from Work
- **THEN** evt-001 SHALL be classified normally (create or skip based on mapping)

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

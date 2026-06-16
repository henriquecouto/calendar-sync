# Event Sync

## Purpose

Detect unsynced events via a local mapping table and create corresponding events in a target calendar using a user-provided name. Also detect and propagate deletions when source events are removed.

## Requirements

### Requirement: Detect already-synced events
The system SHALL query the local mapping table to determine whether a source event (identified by source calendar ID + source event ID) has already been synced to a target calendar. If already synced, the system SHALL compare the source event's start time, end time, and title with the target event's fields and update the target event if any differ. If the target event's start or end time is null, the system SHALL skip the event. If no fields differ, the event is skipped.

#### Scenario: Event is already synced with no changes
- **WHEN** a source event's (calendar_id, event_id) pair exists in the mapping table and its start, end, and title match the target event
- **THEN** the system skips that event

#### Scenario: Event is already synced with time change
- **WHEN** a source event's (calendar_id, event_id) pair exists in the mapping table and its start or end time differ from the target event
- **THEN** the target event is updated with the new times

#### Scenario: Event is already synced with title change
- **WHEN** a source event's (calendar_id, event_id) pair exists in the mapping table and its title differs from the target event's description
- **THEN** the target event's description is updated to the new source title

#### Scenario: Event is not yet synced
- **WHEN** a source event's (calendar_id, event_id) pair is absent from the mapping table
- **THEN** the system marks it for sync and creates a target event

#### Scenario: Target event has null times
- **WHEN** a source event's (calendar_id, event_id) pair exists in the mapping table and the target event's start or end time is null
- **THEN** the system skips the event without crashing

### Requirement: Create synced event with user-provided name
The system SHALL create a target event using the user-configured sync name (not the original event title). The target event SHALL copy the source event's start time and end time. The target event's description SHALL be set to the original source event title.

#### Scenario: Synced event uses custom name and preserves source title as description
- **WHEN** the user has configured "Busy" as the sync name and a source event titled "Doctor Appointment" appears
- **THEN** the target event has the title "Busy", the same start/end times as the source event, and description "Doctor Appointment"

### Requirement: Record sync mappings
After successfully creating a target event, the system SHALL insert a row into the mapping table recording (source_calendar_id, source_event_id, target_calendar_id, target_event_id, synced_at). When a source event is deleted, the system SHALL remove the corresponding mapping row after deleting the target event.

#### Scenario: Mapping recorded after sync
- **WHEN** a source event is synced and a target event is created with ID "TGT-456"
- **THEN** the mapping table contains a row linking source event "SRC-123" (calendar 1) to target event "TGT-456" (calendar 2) with the current timestamp

#### Scenario: Duplicate mapping prevented
- **WHEN** the same source event is encountered twice before the first sync completes
- **THEN** the UNIQUE constraint on (source_calendar_id, source_event_id) prevents a duplicate mapping and a second target event is not created

#### Scenario: Mapping removed on source event deletion
- **WHEN** a source event "SRC-789" with mapping to target event "TGT-012" is deleted from the source calendar
- **THEN** the mapping row is removed after the target event is deleted

### Requirement: Run full sync cycle
The system SHALL execute a sync cycle: list source events (from now to now+30d), query mapping table, for each mapped source event absent from the fetch window check the target event's end time against a 7-day threshold (skip if older, confirm via source-by-ID if recent), create target events for unmapped source events, update target events for already-mapped source events whose fields changed, and record new mappings.

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

#### Scenario: Old past event is ignored
- **WHEN** a synced source event is absent from the fetch window AND its target event's end time is more than 7 days in the past
- **THEN** the system does NOT delete the target event and does NOT fetch the source event

#### Scenario: Recent past event with source still exists
- **WHEN** a synced source event is absent from the fetch window AND its target event's end time is within 7 days AND a direct ID fetch confirms the source still exists
- **THEN** the system re-classifies the event (compares with target and updates if fields differ) rather than deleting

#### Scenario: Recent past event with source confirmed deleted
- **WHEN** a synced source event is absent from the fetch window AND its target event's end time is within 7 days AND a direct ID fetch confirms the source is gone
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

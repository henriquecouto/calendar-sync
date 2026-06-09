# Event Sync

## Purpose

Detect unsynced events via a local mapping table and create corresponding events in a target calendar using a user-provided name. Also detect and propagate deletions when source events are removed.

## Requirements

### Requirement: Detect already-synced events
The system SHALL query the local mapping table to determine whether a source event (identified by source calendar ID + source event ID) has already been synced to a target calendar.

#### Scenario: Event is already synced
- **WHEN** a source event's (calendar_id, event_id) pair exists in the mapping table
- **THEN** the system skips that event and does not create a duplicate in the target calendar

#### Scenario: Event is not yet synced
- **WHEN** a source event's (calendar_id, event_id) pair is absent from the mapping table
- **THEN** the system marks it for sync and creates a target event

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
The system SHALL execute a sync cycle: list source events, query mapping table, delete target events for orphaned mappings (source event no longer exists), create target events for unmapped source events, and record new mappings.

#### Scenario: Full sync with new events
- **WHEN** the source calendar has 3 events and none are in the mapping table
- **THEN** the system creates 3 target events with the user-provided name and inserts 3 mapping rows

#### Scenario: Full sync with mixed state
- **WHEN** the source calendar has 5 events and 2 are already mapped
- **THEN** the system creates 3 target events for the unmapped ones and skips 2

#### Scenario: Full sync with deleted source event
- **WHEN** the source calendar previously had 3 events (all synced) and now has only 2
- **THEN** the system deletes the target event for the missing source event, removes its mapping, and leaves the other 2 untouched

#### Scenario: Full sync with both additions and deletions
- **WHEN** the source calendar had 4 synced events and now has 3 (1 deleted, 1 new added, 2 unchanged)
- **THEN** the system deletes 1 target event, creates 1 new target event, and skips 2

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

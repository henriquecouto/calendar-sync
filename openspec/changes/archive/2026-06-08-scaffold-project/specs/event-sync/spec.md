## ADDED Requirements

### Requirement: Detect already-synced events
The system SHALL query the local mapping table to determine whether a source event (identified by source calendar ID + source event ID) has already been synced to a target calendar.

#### Scenario: Event is already synced
- **WHEN** a source event's (calendar_id, event_id) pair exists in the mapping table
- **THEN** the system skips that event and does not create a duplicate in the target calendar

#### Scenario: Event is not yet synced
- **WHEN** a source event's (calendar_id, event_id) pair is absent from the mapping table
- **THEN** the system marks it for sync and creates a target event

### Requirement: Create synced event with user-provided name
The system SHALL create a target event using the user-configured sync name (not the original event title). The target event SHALL copy the source event's start time and end time.

#### Scenario: Synced event uses custom name
- **WHEN** the user has configured "Busy" as the sync name and a source event titled "Doctor Appointment" appears
- **THEN** the target event has the title "Busy" but the same start/end times as the source event

### Requirement: Record sync mappings
After successfully creating a target event, the system SHALL insert a row into the mapping table recording (source_calendar_id, source_event_id, target_calendar_id, target_event_id, synced_at).

#### Scenario: Mapping recorded after sync
- **WHEN** a source event is synced and a target event is created with ID "TGT-456"
- **THEN** the mapping table contains a row linking source event "SRC-123" (calendar 1) to target event "TGT-456" (calendar 2) with the current timestamp

#### Scenario: Duplicate mapping prevented
- **WHEN** the same source event is encountered twice before the first sync completes
- **THEN** the UNIQUE constraint on (source_calendar_id, source_event_id) prevents a duplicate mapping and a second target event is not created

### Requirement: Run full sync cycle
The system SHALL execute a sync cycle: list source events, query mapping table, identify unsynced events, create target events for each, and record mappings.

#### Scenario: Full sync with new events
- **WHEN** the source calendar has 3 events and none are in the mapping table
- **THEN** the system creates 3 target events with the user-provided name and inserts 3 mapping rows

#### Scenario: Full sync with mixed state
- **WHEN** the source calendar has 5 events and 2 are already mapped
- **THEN** the system creates 3 target events for the unmapped ones and skips 2

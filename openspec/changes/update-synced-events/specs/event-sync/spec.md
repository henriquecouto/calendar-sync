## MODIFIED Requirements

### Requirement: Detect already-synced events
The system SHALL query the local mapping table to determine whether a source event (identified by source calendar ID + source event ID) has already been synced to a target calendar. If already synced, the system SHALL compare the source event's start time, end time, and title with the target event's fields and update the target event if any differ. If no fields differ, the event is skipped.

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

### Requirement: Run full sync cycle
The system SHALL execute a sync cycle: list source events, query mapping table, delete target events for orphaned mappings (source event no longer exists), create target events for unmapped source events, update target events for already-mapped source events whose fields changed, and record new mappings.

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

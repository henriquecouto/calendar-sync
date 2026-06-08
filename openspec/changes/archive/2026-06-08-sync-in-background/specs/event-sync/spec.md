## MODIFIED Requirements

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

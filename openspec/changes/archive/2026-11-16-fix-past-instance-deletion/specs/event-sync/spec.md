# event-sync — Delta Spec

## MODIFIED Requirements

### Requirement: Run full sync cycle
The system SHALL execute a sync cycle for a given profile: list source events from now to now plus the profile's configured sync window, query the mapping table filtered by profile ID and source calendar, and classify each listed source event individually by its (source_event_id, source_instance_id) pair. For each mapped source event absent from the listing, the system SHALL resolve the orphan based on the mapping's kind and the target event's end time. If the mapping has a non-null `source_instance_id` (occurrence of a recurring series) and the target event's end time is already in the past, the system SHALL keep the target event and its mapping — past occurrences are never touched. If the mapping has a non-null `source_instance_id` and the target event's end time is still in the future, the system SHALL fetch the series master by `source_event_id`: if the master exists, the occurrence was moved or deleted as an exception, and the system SHALL delete the target event and remove its mapping; if the master is gone, the whole series was deleted, and the system SHALL delete the target event and remove its mapping. If the mapping has a null `source_instance_id` (non-recurring event), the system SHALL check the target event's end time against a 7-day threshold: if the target event's end time is more than 7 days in the past, the system SHALL keep it; otherwise the system SHALL fetch the source event by ID — if found, re-classify it (update/create path); if not found, delete the target event and remove its mapping. The system SHALL create target events for unmapped source events, update target events for already-synced source events whose fields changed, and record new mappings with the profile ID. Occurrences of recurring series SHALL be classified directly; the series master is fetched only during orphan resolution, never to create a recurring target event.

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

#### Scenario: Full sync with recurring event expands to instances
- **WHEN** the source calendar has a recurring event "Weekly Standup" (base ID "100", 5 instances in window)
- **THEN** the system creates 5 independent target events, one per instance
- **AND** no target event SHALL be recurring
- **AND** 5 mapping rows SHALL be recorded, one per instance id

#### Scenario: Moved occurrence is deleted from old slot and created at new time
- **WHEN** an occurrence of series "100" previously at "100@t1" (mapped, target in the future) moves to "100@t2" in the next cycle
- **AND** the series master still exists
- **THEN** the system deletes the target event for "100@t1" and removes its mapping
- **AND** the system creates a new target event for "100@t2" and records a new mapping

#### Scenario: Deleted occurrence is removed from target
- **WHEN** one occurrence of series "100" is deleted as an exception (no longer listed)
- **AND** the series master still exists
- **AND** the orphaned occurrence's target event is in the future
- **THEN** the system deletes that occurrence's target event and removes its mapping
- **AND** other occurrences of the series are unaffected

#### Scenario: Deleted series removes all its instances
- **WHEN** the recurring series "100" is deleted from the source calendar
- **AND** 3 occurrence mappings exist with target events in the future
- **THEN** the system deletes all 3 target events and removes all 3 mappings

#### Scenario: Recently passed occurrence is kept
- **WHEN** a synced occurrence of series "100" is absent from the listing because its time has already passed
- **AND** its target event's end time is in the past but within the last 7 days
- **AND** the series master still exists
- **THEN** the system does NOT delete the target event and does NOT remove its mapping

#### Scenario: Deleted series keeps an already-passed occurrence
- **WHEN** the recurring series "100" is deleted from the source calendar
- **AND** one occurrence mapping has a target event whose end time is already in the past
- **AND** other occurrence mappings have target events in the future
- **THEN** the system deletes the target events in the future and removes their mappings
- **AND** the system does NOT delete the past target event and does NOT remove its mapping

#### Scenario: Aged-out occurrence is kept
- **WHEN** a synced occurrence is absent from the listing because it fell out of the window
- **AND** its target event's end time is in the past
- **THEN** the system does NOT delete the target event and does NOT remove its mapping

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

#### Scenario: Full sync uses profile sync window
- **WHEN** a profile has a sync window of 90 days
- **THEN** the source listing SHALL cover from now to now+90 days
- **AND** occurrences within that horizon SHALL be classified

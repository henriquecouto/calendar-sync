## MODIFIED Requirements

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

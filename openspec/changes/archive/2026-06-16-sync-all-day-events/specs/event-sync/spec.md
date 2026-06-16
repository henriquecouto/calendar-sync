## MODIFIED Requirements

### Requirement: Detect already-synced events
The system SHALL query the local mapping table to determine whether a source event (identified by source calendar ID + source event ID) has already been synced to a target calendar. If already synced, the system SHALL compare the source event's start time, end time, title, and all-day flag with the target event's fields and update the target event if any differ. If the target event's start or end time is null and the event is not an all-day event, the system SHALL skip the event. For all-day events with null start or end times on the target, the system SHALL re-create the target event. If no fields differ, the event is skipped.

#### Scenario: Event is already synced with no changes
- **WHEN** a source event's (calendar_id, event_id) pair exists in the mapping table and its start, end, title, and all-day flag match the target event
- **THEN** the system skips that event

#### Scenario: Event is already synced with time change
- **WHEN** a source event's (calendar_id, event_id) pair exists in the mapping table and its start or end time differ from the target event
- **THEN** the target event is updated with the new times

#### Scenario: Event is already synced with title change
- **WHEN** a source event's (calendar_id, event_id) pair exists in the mapping table and its title differs from the target event's description
- **THEN** the target event's description is updated to the new source title

#### Scenario: Event is already synced with all-day status change
- **WHEN** a source event's (calendar_id, event_id) pair exists in the mapping table and its all-day flag differs from the target event's all-day flag
- **THEN** the target event is updated with the new all-day status

#### Scenario: Event is not yet synced
- **WHEN** a source event's (calendar_id, event_id) pair is absent from the mapping table
- **THEN** the system marks it for sync and creates a target event

#### Scenario: Non-all-day target event has null times
- **WHEN** a source event's (calendar_id, event_id) pair exists in the mapping table and the target event is not all-day and its start or end time is null
- **THEN** the system skips the event without crashing

#### Scenario: All-day target event has null times
- **WHEN** a source event's (calendar_id, event_id) pair exists in the mapping table and the target event is all-day and its start or end time is null
- **THEN** the system re-creates the target event rather than skipping it

### Requirement: Create synced event with user-provided name
The system SHALL create a target event using the user-configured sync name. For all-day source events, the target SHALL be a timed event (allDay=false) at midnight in the device's local timezone: start = local midnight of the first day, end = local midnight of the day after the last day. For timed (non-all-day) source events, the target SHALL copy start/end directly with allDay=false. The target event's description SHALL be set to the original source event title.

#### Scenario: Synced event uses custom name and preserves source title as description
- **WHEN** the user has configured "Busy" as the sync name and a timed source event titled "Doctor Appointment" appears
- **THEN** the target event has the title "Busy", the same start/end times as the source, and description "Doctor Appointment"

#### Scenario: Single-day all-day source creates timed target at local midnight
- **WHEN** a source all-day event on June 23 is synced on a device in UTC-3
- **THEN** the target is a timed event (allDay=false) with start=June 23 00:00 local, end=June 24 00:00 local

#### Scenario: Multi-day all-day source creates timed target spanning full days
- **WHEN** a source all-day event from June 23 to June 25 is synced
- **THEN** the target is a timed event (allDay=false) with start=June 23 00:00 local, end=June 26 00:00 local

### Requirement: Run full sync cycle
The system SHALL execute a sync cycle: list source events (from now to now+30d), query mapping table, for each mapped source event absent from the fetch window check the target event's end time against a 7-day threshold (skip if older, confirm via source-by-ID if recent). All-day target events with null end times SHALL be treated as recent and confirmed via source-by-ID rather than having their mappings deleted. Create target events for unmapped source events, update target events for already-mapped source events whose fields changed (including all-day flag), and record new mappings.

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

#### Scenario: Orphan all-day mapping with null end time
- **WHEN** a synced source event is absent from the fetch window AND the target event is all-day with null end time
- **THEN** the system treats it as recent and confirms via source-by-ID rather than deleting the mapping

# event-sync (delta)

## MODIFIED Requirements

### Requirement: Detect already-synced events
The system SHALL query the local mapping table to determine whether a source event (identified by profile ID + source calendar ID + source event ID) has already been synced to a target calendar for a given profile. If already synced, the system SHALL compare the source event's start time, end time, and title with the target event's fields and update the target event if any differ. If the target event's start or end time is null, the system SHALL skip the event. If no fields differ, the event is skipped. When comparing the source event's title against the target event's description, the system SHALL use `contains` (not `startsWith` or exact match) to handle descriptions that may be wrapped in HTML by calendar providers.

#### Scenario: Event is already synced with title change
- **WHEN** a source event's (profile_id, calendar_id, event_id) pair exists in the mapping table and its title is NOT contained anywhere in the target event's description
- **THEN** the target event's description is updated to the new source title

#### Scenario: HTML-wrapped description is recognized as unchanged
- **WHEN** the target event's description is `<html><body>Doctor Appointment<br>---<br>🔃 Automatically created by CalSync</body></html>`
- **AND** the source event's title is `Doctor Appointment`
- **THEN** the system SHALL detect no title change via `contains("Doctor Appointment")`
- **AND** the event SHALL be skipped if no other fields changed

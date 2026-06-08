## MODIFIED Requirements

### Requirement: Create synced event with user-provided name
The system SHALL create a target event using the user-configured sync name (not the original event title). The target event SHALL copy the source event's start time and end time. The target event's description SHALL be set to the original source event title.

#### Scenario: Synced event uses custom name and preserves source title as description
- **WHEN** the user has configured "Busy" as the sync name and a source event titled "Doctor Appointment" appears
- **THEN** the target event has the title "Busy", the same start/end times as the source event, and description "Doctor Appointment"

## MODIFIED Requirements

### Requirement: Retrieve a single event by ID
The system SHALL retrieve a single calendar event by its event ID directly, without being constrained by any time window. The retrieval SHALL use a direct ID-based lookup rather than fetching all events and scanning.

#### Scenario: Past event retrieved by ID
- **WHEN** the system requests an event by its ID and the event's start time is in the past
- **THEN** the event is returned with all its fields (ID, title, start, end, description)

#### Scenario: Future event retrieved by ID
- **WHEN** the system requests an event by its ID and the event's start time is in the future
- **THEN** the event is returned with all its fields

#### Scenario: Non-existent event ID
- **WHEN** the system requests an event by an ID that does not exist in the calendar
- **THEN** the system returns null without error

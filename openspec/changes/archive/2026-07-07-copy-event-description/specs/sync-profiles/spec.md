## MODIFIED Requirements

### Requirement: Profile data model
Each sync profile SHALL have a unique UUID identifier, a user-defined name, source calendar ID, target calendar ID, sync event name, sync interval in minutes, enabled boolean, copy description boolean, and copy location boolean. The sync event name SHALL be optional — an empty value means the target event retains the source event's original title. Both `copyDescription` and `copyLocation` SHALL default to `false`. The profile name SHALL be unique across all profiles. Profiles SHALL be persisted in a local SQLite `sync_profiles` table and survive app restarts.

#### Scenario: Profile fields
- **WHEN** a profile is created
- **THEN** it SHALL contain a unique ID, a name, source calendar ID, target calendar ID, event name, interval minutes, enabled flag, copyDescription flag, and copyLocation flag

#### Scenario: Profile persistence across restarts
- **WHEN** a profile is created and the app is restarted
- **THEN** the profile SHALL still be present with all fields preserved

### Requirement: Profile form structure
The profile create/edit form SHALL be organized into a Basic section (always visible) and an Advanced section (collapsed by default). The Basic section SHALL contain the profile name field, source/target calendar pickers, and sync enabled toggle. The Advanced section SHALL contain the sync event name field, fallback interval dropdown, copy location toggle, and copy description toggle. The "Event Naming" and "Schedule" standalone cards SHALL be removed — their fields SHALL move to their respective sections.

#### Scenario: Basic section contains core fields
- **WHEN** the profile form is displayed
- **THEN** the Basic section SHALL show profile name, source calendar picker, target calendar picker, and sync enabled toggle
- **AND** these fields SHALL always be visible (not collapsible)

#### Scenario: Advanced section contains optional fields
- **WHEN** the user expands the Advanced section
- **THEN** it SHALL show sync event name field, fallback interval dropdown, copy location toggle, and copy description toggle

#### Scenario: Advanced section defaults to collapsed
- **WHEN** the profile creation form first appears
- **THEN** the Advanced section SHALL be collapsed

#### Scenario: Editing existing profile shows Advanced expanded if any advanced field is non-default
- **WHEN** editing a profile that has `copyLocation: true` or `copyDescription: true` or a custom event name
- **THEN** the Advanced section SHALL be initially expanded

### Requirement: Create profile
The system SHALL allow the user to create a new sync profile by entering a profile name, selecting a source calendar, target calendar, entering an optional event name, toggling copy location and copy description, choosing an interval, and toggling enable state. The profile SHALL be persisted immediately on save. The profile name SHALL be mandatory (auto-generated from calendars if left empty) and unique. The event name SHALL be optional — an empty value means target events use the source event's original title.

#### Scenario: Create a new profile with custom event name
- **WHEN** the user fills in all profile fields including an event name and saves
- **THEN** a new profile with a unique UUID SHALL be persisted
- **AND** the profile SHALL appear on the dashboard

#### Scenario: Create a new profile with empty event name
- **WHEN** the user leaves the event name empty and saves
- **THEN** the profile SHALL be persisted with an empty event name
- **AND** future syncs SHALL use source event original titles as target event titles

#### Scenario: Profile with empty name auto-generates
- **WHEN** the user leaves the profile name empty, selects source and target calendars, and saves
- **THEN** the system SHALL auto-generate a name like "SourceCal → TargetCal"
- **AND** the profile SHALL be persisted with the auto-generated name

#### Scenario: Profile with duplicate name rejected
- **WHEN** the user saves a profile with a name that already exists
- **THEN** the save SHALL be rejected with a validation error

#### Scenario: Profile with same source and target calendar
- **WHEN** the user selects the same calendar as both source and target
- **THEN** the save SHALL be rejected with a validation error

#### Scenario: Default values for new profile
- **WHEN** the profile creation form first appears
- **THEN** name SHALL be empty, source and target calendars SHALL be unselected, event name SHALL be empty, interval SHALL default to 60 minutes, enabled SHALL default to true, copyDescription SHALL default to false, and copyLocation SHALL default to false

#### Scenario: Create profile with copy location enabled
- **WHEN** the user enables the "Copy location" toggle and saves
- **THEN** the profile SHALL be persisted with `copyLocation: true`

#### Scenario: Create profile with copy description enabled
- **WHEN** the user enables the "Copy description" toggle and saves
- **THEN** the profile SHALL be persisted with `copyDescription: true`

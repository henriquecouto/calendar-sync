## MODIFIED Requirements

### Requirement: Profile data model
Each sync profile SHALL have a unique UUID identifier, a user-defined name, source calendar ID, target calendar ID, sync event name, sync interval in minutes, and enabled boolean. The sync event name SHALL be optional — an empty value means the target event retains the source event's original title. The profile name SHALL be unique across all profiles. Profiles SHALL be persisted in a local SQLite `sync_profiles` table and survive app restarts.

#### Scenario: Profile fields
- **WHEN** a profile is created
- **THEN** it SHALL contain a unique ID, a name, source calendar ID, target calendar ID, event name, interval minutes, and enabled flag

#### Scenario: Profile persistence across restarts
- **WHEN** a profile is created and the app is restarted
- **THEN** the profile SHALL still be present with all fields preserved

### Requirement: Create profile
The system SHALL allow the user to create a new sync profile by entering a profile name, selecting a source calendar, target calendar, entering an optional event name, choosing an interval, and toggling enable state. The profile SHALL be persisted immediately on save. The profile name SHALL be mandatory (auto-generated from calendars if left empty) and unique. The event name SHALL be optional — an empty value means target events use the source event's original title.

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
- **THEN** name SHALL be empty, source and target calendars SHALL be unselected, event name SHALL be empty, interval SHALL default to 60 minutes, and enabled SHALL default to true

### Requirement: Enable and disable individual profiles
Each profile SHALL have an independent enabled/disabled toggle. Disabled profiles SHALL be skipped during both manual and background sync. The toggle SHALL be changeable from both the profile config screen and the profile card on the dashboard. An empty event name SHALL NOT cause a profile to be skipped — an empty event name is a valid configuration meaning "use original titles."

#### Scenario: Disable a profile from dashboard
- **WHEN** the user toggles a profile card's enabled switch to off
- **THEN** the profile SHALL be persisted as disabled
- **AND** the profile SHALL be skipped in future sync cycles

#### Scenario: Sync all skips disabled profiles
- **WHEN** "Sync All" is triggered and 2 of 3 profiles are disabled
- **THEN** only the 1 enabled profile SHALL execute a sync cycle

#### Scenario: Sync proceeds for profile with empty event name
- **WHEN** a profile has an empty event name, is enabled, and a sync is triggered
- **THEN** the profile SHALL execute a sync cycle normally using source event original titles

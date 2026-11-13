# sync-profiles — Delta Spec

## MODIFIED Requirements

### Requirement: Profile data model
Each sync profile SHALL have a unique UUID identifier, a user-defined name, source calendar ID, target calendar ID, sync event name, sync interval in minutes, sync window in days (one of 30, 90, 180, or 365), enabled boolean, copy description boolean, copy location boolean, and omit source title boolean. The sync event name SHALL be optional — an empty value means the target event retains the source event's original title. Both `copyDescription` and `copyLocation` SHALL default to `false`. `omitSourceTitle` SHALL default to `false`. The sync window SHALL default to 30 days (1 month). The profile name SHALL be unique across all profiles. Profiles SHALL be persisted in a local SQLite `sync_profiles` table and survive app restarts.

#### Scenario: Profile fields
- **WHEN** a profile is created
- **THEN** it SHALL contain a unique ID, a name, source calendar ID, target calendar ID, event name, interval minutes, sync window days, enabled flag, copyDescription flag, copyLocation flag, and omitSourceTitle flag

#### Scenario: Profile persistence across restarts
- **WHEN** a profile is created and the app is restarted
- **THEN** the profile SHALL still be present with all fields preserved

### Requirement: Profile form structure

The profile create/edit form SHALL be organized into a Basic section (always visible) and an Advanced section (collapsed by default). The Basic section SHALL contain the profile name field, source/target calendar pickers, and sync enabled toggle. The Advanced section SHALL contain the sync event name field, fallback interval dropdown, sync window dropdown, copy location toggle, copy description toggle, and omit source title toggle. The "Event Naming" and "Schedule" standalone cards SHALL be removed — their fields SHALL move to their respective sections.

#### Scenario: Basic section contains core fields

- **WHEN** the profile form is displayed
- **THEN** the Basic section SHALL show profile name, source calendar picker, target calendar picker, and sync enabled toggle
- **AND** these fields SHALL always be visible (not collapsible)

#### Scenario: Advanced section contains optional fields

- **WHEN** the user expands the Advanced section
- **THEN** it SHALL show sync event name field, fallback interval dropdown, sync window dropdown, copy location toggle, copy description toggle, and omit source title toggle

#### Scenario: Advanced section defaults to collapsed

- **WHEN** the profile creation form first appears
- **THEN** the Advanced section SHALL be collapsed

#### Scenario: Editing existing profile shows Advanced expanded if any advanced field is non-default

- **WHEN** editing a profile that has `copyLocation: true` or `copyDescription: true` or `omitSourceTitle: true` or a custom event name or a non-default sync window
- **THEN** the Advanced section SHALL be initially expanded

### Requirement: Create profile
The system SHALL allow the user to create a new sync profile by entering a profile name, selecting a source calendar, target calendar, entering an optional event name, toggling copy location, copy description, and omit source title, choosing an interval, choosing a sync window, and toggling enable state. The profile SHALL be persisted immediately on save. The profile name SHALL be mandatory (auto-generated from calendars if left empty) and unique. The event name SHALL be optional — an empty value means target events use the source event's original title.

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
- **THEN** name SHALL be empty, source and target calendars SHALL be unselected, event name SHALL be empty, interval SHALL default to 60 minutes, sync window SHALL default to 1 month, enabled SHALL default to true, copyDescription SHALL default to false, copyLocation SHALL default to false, and omitSourceTitle SHALL default to false

#### Scenario: Create profile with copy location enabled

- **WHEN** the user enables the "Copy location" toggle and saves
- **THEN** the profile SHALL be persisted with `copyLocation: true`

#### Scenario: Create profile with copy description enabled

- **WHEN** the user enables the "Copy description" toggle and saves
- **THEN** the profile SHALL be persisted with `copyDescription: true`

#### Scenario: Create profile with omit source title enabled

- **WHEN** the user enables the "Omit source event title" toggle and saves
- **THEN** the profile SHALL be persisted with `omitSourceTitle: true`

## ADDED Requirements

### Requirement: Sync window selection
The system SHALL let the user choose a sync window per profile from exactly four options: 1 month (30 days), 3 months (90 days), 6 months (180 days), and 1 year (365 days). The chosen window SHALL be persisted on the profile and SHALL determine the horizon of the source event listing for that profile's sync cycles (from now to now+window). The window SHALL default to 1 month for new profiles. Changing the window SHALL take effect on the next sync cycle and SHALL NOT retroactively delete or create events.

#### Scenario: Window options offered
- **WHEN** the user opens the sync window selector in the profile form
- **THEN** exactly four options are offered: 1 month, 3 months, 6 months, and 1 year

#### Scenario: Default window is 1 month
- **WHEN** a new profile is created without touching the sync window selector
- **THEN** the profile SHALL persist sync_window_days=30

#### Scenario: Selecting a longer window persists
- **WHEN** the user selects "6 months" and saves the profile
- **THEN** the profile SHALL persist sync_window_days=180
- **AND** the profile SHALL still have that value after an app restart

#### Scenario: Window applies to the next sync cycle
- **WHEN** a profile has sync_window_days=365
- **AND** a sync cycle runs
- **THEN** the source listing SHALL cover from now to now+365 days

#### Scenario: Window change does not delete existing target events
- **WHEN** the user shrinks the sync window from 12 months to 1 month and saves
- **AND** a sync cycle runs
- **THEN** target events beyond the new horizon that are still in the future SHALL be removed only by normal orphan processing rules
- **AND** no immediate mass deletion SHALL be triggered by the window change itself

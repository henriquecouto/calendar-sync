## ADDED Requirements

### Requirement: Profile controls source description copying
Each sync profile SHALL have a `copyDescription` boolean field, defaulting to `false`. When `true`, the sync engine SHALL copy the source event's description into the target event's description, prepended above the original title and sync marker block. When `false` or when the source event has a null or empty description, the target event description SHALL remain as the original title + sync marker only (no change from current behavior).

#### Scenario: Copy description enabled with non-empty source description
- **WHEN** a profile has `copyDescription: true`
- **AND** the source event has description "Meeting agenda: Q3 planning"
- **THEN** the target event description SHALL be:
  ```
  Meeting agenda: Q3 planning

  Doctor Appointment
  ---
  🔃 Automatically created by CalSync
  ```

#### Scenario: Copy description enabled with null source description
- **WHEN** a profile has `copyDescription: true`
- **AND** the source event has `description: null`
- **THEN** the target event description SHALL be:
  ```
  Doctor Appointment
  ---
  🔃 Automatically created by CalSync
  ```
- **AND** no blank line or empty description block SHALL be prepended

#### Scenario: Copy description enabled with empty source description
- **WHEN** a profile has `copyDescription: true`
- **AND** the source event has `description: ""`
- **THEN** the target event description SHALL be:
  ```
  Doctor Appointment
  ---
  🔃 Automatically created by CalSync
  ```
- **AND** no blank line or empty description block SHALL be prepended

#### Scenario: Copy description disabled preserves current behavior
- **WHEN** a profile has `copyDescription: false`
- **AND** the source event has description "Meeting agenda: Q3 planning"
- **THEN** the target event description SHALL be:
  ```
  Doctor Appointment
  ---
  🔃 Automatically created by CalSync
  ```
- **AND** the source description SHALL NOT appear in the target description

#### Scenario: Copy description persists across app restarts
- **WHEN** a profile is saved with `copyDescription: true` and the app is restarted
- **THEN** the profile SHALL still have `copyDescription: true`

#### Scenario: Copy description on update path
- **WHEN** a source event is already synced and its description changes
- **AND** the profile has `copyDescription: true`
- **THEN** the target event description SHALL be updated to include the new source description

### Requirement: Profile controls source location copying
Each sync profile SHALL have a `copyLocation` boolean field, defaulting to `false`. When `true`, the sync engine SHALL pass the source event's location to the target event's location field. When `false` or when the source event has a null location, the target event SHALL have no location.

#### Scenario: Copy location enabled with non-null source location
- **WHEN** a profile has `copyLocation: true`
- **AND** the source event has location "Conference Room A"
- **THEN** the target event SHALL be created with `location: "Conference Room A"`

#### Scenario: Copy location enabled with null source location
- **WHEN** a profile has `copyLocation: true`
- **AND** the source event has `location: null`
- **THEN** the target event SHALL be created with `location: null` (or absent)

#### Scenario: Copy location disabled with non-null source location
- **WHEN** a profile has `copyLocation: false`
- **AND** the source event has location "Conference Room A"
- **THEN** the target event SHALL be created with `location: null` (or absent)

#### Scenario: Copy location persists across app restarts
- **WHEN** a profile is saved with `copyLocation: true` and the app is restarted
- **THEN** the profile SHALL still have `copyLocation: true`

#### Scenario: Copy location on update path
- **WHEN** a source event is already synced and its location changes
- **AND** the profile has `copyLocation: true`
- **THEN** the target event location SHALL be updated to the new source location

### Requirement: Profile form has Advanced section with copy toggles
The profile create/edit form SHALL reorganize into Basic and Advanced sections. The Advanced section SHALL be collapsed by default and SHALL contain the sync event name field, fallback interval dropdown, copy location toggle, and copy description toggle.

#### Scenario: Copy toggles appear in Advanced section
- **WHEN** the user opens the profile create or edit form
- **THEN** the Advanced section SHALL contain "Copy location" and "Copy description" toggles
- **AND** both toggles SHALL default to off for new profiles
- **AND** both toggles SHALL reflect persisted values for existing profiles

#### Scenario: Advanced section is collapsed by default
- **WHEN** the user opens the profile create form
- **THEN** the Advanced section SHALL be collapsed
- **AND** the Basic section SHALL be visible

#### Scenario: Toggling Advanced section reveals its fields
- **WHEN** the user taps the Advanced section header
- **THEN** the section SHALL expand to show sync event name, fallback interval, copy location, and copy description

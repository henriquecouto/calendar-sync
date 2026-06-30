# sync-profiles

## Purpose

Manage multiple synchronization profiles, each representing an independent source→target calendar pair with its own event name, interval, and enabled state.

## ADDED Requirements

### Requirement: Profile data model
Each sync profile SHALL have a unique UUID identifier, a user-defined name, source calendar ID, target calendar ID, sync event name, sync interval in minutes, and enabled boolean. The sync event name SHALL be optional — an empty value means the target event retains the source event's original title. The profile name SHALL be unique across all profiles. Profiles SHALL be persisted in a local SQLite `sync_profiles` table and survive app restarts.

#### Scenario: Profile fields
- **WHEN** a profile is created
- **THEN** it SHALL contain a unique ID, a name, source calendar ID, target calendar ID, event name, interval minutes, and enabled flag

#### Scenario: Profile persistence across restarts
- **WHEN** a profile is created and the app is restarted
- **THEN** the profile SHALL still be present with all fields preserved

### Requirement: Profile name
Each profile SHALL have a mandatory name. If the user leaves the name field empty, the system SHALL auto-generate a name from the selected calendars in the format `"SourceName → TargetName"`. Profile names SHALL be unique across all profiles. The name SHALL be editable at any time.

#### Scenario: User provides a name
- **WHEN** the user enters "Work Sync" as the profile name and saves
- **THEN** the profile is saved with name "Work Sync"

#### Scenario: Auto-generated name when user leaves name empty
- **WHEN** the user selects source calendar "Personal" and target calendar "Work" and leaves the name field empty
- **THEN** the system SHALL auto-generate the name "Personal → Work" before saving

#### Scenario: Duplicate name rejected
- **WHEN** a profile named "Work Sync" already exists and the user tries to create or rename another profile to "Work Sync"
- **THEN** the save SHALL be rejected with a validation error indicating the name is already in use

#### Scenario: Rename profile
- **WHEN** the user edits a profile and changes its name from "Work Sync" to "Office Sync"
- **THEN** the new name SHALL be persisted and reflected everywhere the profile is displayed

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

### Requirement: Edit profile
The system SHALL allow the user to edit any field of an existing profile, including the name. Changes SHALL be persisted immediately and reflected on the dashboard. Name uniqueness SHALL be enforced on edit (the new name must not conflict with another profile's name).

#### Scenario: Edit profile name
- **WHEN** the user changes the name of an existing profile and saves
- **THEN** the new name SHALL be persisted and displayed everywhere the profile appears
- **AND** if the new name conflicts with another profile, the save SHALL be rejected

#### Scenario: Edit profile source calendar
- **WHEN** the user changes the source calendar of an existing profile and saves
- **THEN** the new source calendar SHALL be used in future syncs
- **AND** existing mappings from the old source calendar SHALL remain in the mapping table under the same profile ID

### Requirement: Delete profile
The system SHALL allow the user to delete a profile. Deleting a profile SHALL remove the profile row and all associated sync mappings and status entries.

#### Scenario: Delete a profile with mappings
- **WHEN** the user deletes a profile that has existing sync mappings and status history
- **THEN** the profile row, all its mappings, and all its status entries SHALL be removed from the database

#### Scenario: Delete confirmation
- **WHEN** the user taps the delete action on a profile
- **THEN** a confirmation dialog SHALL appear before the profile is deleted

### Requirement: List and load profiles
The system SHALL load all profiles on demand. The dashboard SHALL display each profile as a card in a scrollable list. Profiles with no configured source or target calendar SHALL still appear in the list but SHALL be skipped during sync.

#### Scenario: Dashboard shows all profiles
- **WHEN** the dashboard loads and 3 profiles exist
- **THEN** each profile SHALL appear as a card showing the profile name as the card title, source→target calendar names as secondary info, event name, interval, enabled state, and last sync time

#### Scenario: Dashboard with no profiles
- **WHEN** the dashboard loads and no profiles exist
- **THEN** an empty state SHALL be displayed with a "Create Profile" action

#### Scenario: Profile with unconfigured calendar
- **WHEN** a profile's source or target calendar is null (never selected)
- **THEN** the profile SHALL still appear in the dashboard list
- **AND** the profile SHALL be skipped during sync without error

#### Scenario: Profile with deleted calendar
- **WHEN** a profile's source or target calendar existed at configuration time but has since been removed from the device (account deleted, app uninstalled)
- **THEN** the profile card SHALL show a warning indicator (orange icon, muted styling)
- **AND** the profile SHALL be skipped during sync without error
- **AND** the profile SHALL NOT be automatically deleted
- **AND** the user SHALL be able to edit the profile to select a replacement calendar or delete the profile manually

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

### Requirement: Profile uniqueness constraint
The system SHALL prevent creating a profile with the same source calendar ID and target calendar ID combination as an existing profile. This constraint prevents duplicate target events (two profiles syncing the same source→target pair would each create a target event for every source event). This constraint is separate from the `sync_created_events` loop-prevention table — the constraint blocks duplicate profiles, the table blocks sync loops between bidirectional profiles.

#### Scenario: Duplicate source-target pair rejected
- **WHEN** the user attempts to create a profile with source "A" and target "B" and another profile already uses source "A" and target "B"
- **THEN** the save SHALL be rejected with a validation error

#### Scenario: Different direction is allowed
- **WHEN** a profile exists with source "A" and target "B"
- **AND** the user creates a profile with source "B" and target "A"
- **THEN** the new profile SHALL be accepted (different direction is a different pair)

### Requirement: Profile-based Workmanager interval
The system SHALL manage the periodic background task interval based on all enabled profiles. The task SHALL use the minimum interval among enabled profiles. If no profiles are enabled, the periodic task SHALL be cancelled.

#### Scenario: Single profile determines interval
- **WHEN** one profile is enabled with interval 30 minutes
- **THEN** the periodic task SHALL be registered with a 30-minute frequency

#### Scenario: Multiple profiles use minimum interval
- **WHEN** two profiles are enabled with intervals 15 minutes and 60 minutes
- **THEN** the periodic task SHALL be registered with a 15-minute frequency

#### Scenario: No enabled profiles cancels task
- **WHEN** all profiles are disabled
- **THEN** the periodic background task SHALL be cancelled

#### Scenario: Interval updates when profiles change
- **WHEN** the set of enabled profiles or their intervals change
- **THEN** the periodic task interval SHALL be updated within 5 seconds to reflect the new minimum

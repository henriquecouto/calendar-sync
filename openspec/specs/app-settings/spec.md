# App Settings

## Purpose

Persist per-profile sync configuration (source calendar, target calendar, event name, interval, enabled) across app restarts via SQLite storage. Migrate legacy flat SharedPreferences on upgrade.

## Requirements

### Requirement: Save sync configuration
The system SHALL persist per-profile sync configuration (source calendar ID, target calendar ID, sync event name, sync interval in minutes, and sync enabled flag) via a `ProfileService` that stores profiles in a SQLite `sync_profiles` table. Each profile SHALL have a unique UUID. These SHALL survive app restarts. On first launch after upgrade, any existing flat SharedPreferences configuration SHALL be migrated into a single default profile.

#### Scenario: User saves profile configuration
- **WHEN** the user creates a profile selecting "Calendar A" as source, "Calendar B" as target, enters "Busy" as the sync name, sets the interval to 30 minutes, and enables sync
- **THEN** a new profile with a unique UUID SHALL be persisted
- **AND** those values SHALL be restored when the app restarts

#### Scenario: Default values for new profile
- **WHEN** the profile creation form first opens
- **THEN** source and target calendar IDs SHALL be null, the sync name SHALL be an empty string, the sync interval SHALL default to 60 minutes, and sync enabled SHALL default to true

### Requirement: Load sync configuration
The system SHALL load all persisted profiles from the `sync_profiles` SQLite table on demand.

#### Scenario: Profiles loaded after save
- **WHEN** values were previously saved to a profile
- **THEN** loading the profile SHALL return the exact values that were saved

#### Scenario: Multiple profiles loaded
- **WHEN** 3 profiles were previously saved
- **THEN** loading SHALL return all 3 profiles with their full configuration

### Requirement: Clear sync configuration
The system SHALL allow the user to delete individual profiles, which SHALL remove the profile row and all associated mappings and status entries from the database. Individual profile fields SHALL be clearable via editing without deleting the entire profile.

#### Scenario: Delete a profile
- **WHEN** the user deletes a profile
- **THEN** the profile SHALL be removed from the database along with all its mappings and status entries
- **AND** other profiles SHALL be unaffected

#### Scenario: Clear individual settings via edit
- **WHEN** the user edits a profile and clears the source calendar selection
- **THEN** the source calendar ID SHALL be set to null for that profile only
- **AND** other profile fields remain unchanged
- **AND** other profiles remain unaffected

### Requirement: Toggle sync enabled state
The system SHALL allow the user to enable or disable sync on a per-profile basis via a boolean setting on each profile. When a profile is disabled, no sync operations SHALL execute for that profile — manual, reactive, or periodic.

#### Scenario: Disable a single profile
- **WHEN** the user sets a specific profile's enabled state to false
- **THEN** that profile SHALL be skipped during "Sync All" and background sync operations
- **AND** other enabled profiles SHALL continue to sync normally

#### Scenario: Re-enable a profile
- **WHEN** the user re-enables a previously disabled profile
- **THEN** the profile SHALL participate in future "Sync All" and background sync operations

### Requirement: One-time settings migration on upgrade
The system SHALL detect existing flat SharedPreferences settings on first launch after upgrade and migrate them into a single default profile. The migration SHALL happen exactly once, tracked by a SharedPreferences flag `profile_migration_done`.

#### Scenario: Migration from v1.x to multi-profile
- **WHEN** the app is upgraded from a single-profile version with existing SharedPreferences settings
- **THEN** a default profile named `"Default"` SHALL be created with the existing source calendar, target calendar, event name, interval, and enabled state
- **AND** the `profile_migration_done` flag SHALL be set to true
- **AND** the old SharedPreferences keys SHALL be cleared

#### Scenario: No migration needed on fresh install
- **WHEN** the app is freshly installed with no prior SharedPreferences settings
- **THEN** no default profile SHALL be created
- **AND** the `profile_migration_done` flag SHALL be set to true
- **AND** the dashboard SHALL show the empty state

#### Scenario: Migration does not repeat
- **WHEN** the `profile_migration_done` flag is already true
- **THEN** the migration code SHALL not execute again even if profiles are deleted

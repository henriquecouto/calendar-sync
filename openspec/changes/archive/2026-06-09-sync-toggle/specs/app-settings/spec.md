## MODIFIED Requirements

### Requirement: Save sync configuration
The system SHALL persist five user-configurable settings: source calendar ID, target calendar ID, sync event name, sync interval in minutes, and sync enabled flag. These SHALL survive app restarts.

#### Scenario: User saves configuration
- **WHEN** the user selects "Calendar A" as source, "Calendar B" as target, enters "Busy" as the sync name, sets the interval to 30 minutes, and enables sync
- **THEN** those values are persisted and restored when the app restarts

#### Scenario: Default values
- **WHEN** the app launches for the first time before any settings are saved
- **THEN** source and target calendar IDs are null, the sync name is an empty string, the sync interval defaults to 60 minutes, and sync enabled defaults to true

### Requirement: Load sync configuration
The system SHALL load the saved source calendar ID, target calendar ID, sync event name, sync interval, and sync enabled flag on demand.

#### Scenario: Configuration loaded after save
- **WHEN** values were previously saved
- **THEN** loading returns the exact values that were saved

## ADDED Requirements

### Requirement: Toggle sync enabled state
The system SHALL allow the user to enable or disable all sync activity via a boolean setting. When disabled, no sync operations SHALL execute — manual, reactive, or periodic.

#### Scenario: Disable sync
- **WHEN** the user sets sync enabled to false
- **THEN** the "Sync Now" button is disabled and all background sync triggers exit without performing any sync operations

#### Scenario: Re-enable sync
- **WHEN** the user sets sync enabled from false to true
- **THEN** the "Sync Now" button is re-enabled and future background sync triggers execute normally

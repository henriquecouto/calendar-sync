## MODIFIED Requirements

### Requirement: Save sync configuration
The system SHALL persist four user-configurable settings: source calendar ID, target calendar ID, sync event name, and sync interval in minutes. These SHALL survive app restarts.

#### Scenario: User saves configuration
- **WHEN** the user selects "Calendar A" as source, "Calendar B" as target, enters "Busy" as the sync name, and sets the interval to 30 minutes
- **THEN** those values are persisted and restored when the app restarts

#### Scenario: Default values
- **WHEN** the app launches for the first time before any settings are saved
- **THEN** source and target calendar IDs are null, the sync name is an empty string, and the sync interval defaults to 60 minutes

### Requirement: Load sync configuration
The system SHALL load the saved source calendar ID, target calendar ID, sync event name, and sync interval on demand.

#### Scenario: Configuration loaded after save
- **WHEN** values were previously saved
- **THEN** loading returns the exact values that were saved

### Requirement: Clear sync configuration
The system SHALL allow the user to reset/clear all sync settings individually, including the sync interval.

#### Scenario: Reset source calendar
- **WHEN** the user clears the source calendar setting
- **THEN** the source calendar ID returns to null without affecting other settings

#### Scenario: Reset sync interval
- **WHEN** the user clears the sync interval setting
- **THEN** the sync interval returns to the default of 60 minutes

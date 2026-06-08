# App Settings

## Purpose

Persist user-configurable sync settings (source calendar, target calendar, event name) across app restarts.

## Requirements

### Requirement: Save sync configuration
The system SHALL persist three user-configurable settings: source calendar ID, target calendar ID, and the sync event name. These SHALL survive app restarts.

#### Scenario: User saves configuration
- **WHEN** the user selects "Calendar A" as source, "Calendar B" as target, and enters "Busy" as the sync name
- **THEN** those values are persisted and restored when the app restarts

#### Scenario: Default values
- **WHEN** the app launches for the first time before any settings are saved
- **THEN** source and target calendar IDs are null and the sync name is an empty string

### Requirement: Load sync configuration
The system SHALL load the saved source calendar ID, target calendar ID, and sync event name on demand.

#### Scenario: Configuration loaded after save
- **WHEN** values were previously saved
- **THEN** loading returns the exact values that were saved

### Requirement: Clear sync configuration
The system SHALL allow the user to reset/clear all sync settings individually.

#### Scenario: Reset source calendar
- **WHEN** the user clears the source calendar setting
- **THEN** the source calendar ID returns to null without affecting other settings

## ADDED Requirements

### Requirement: Manual sync gated on sync enabled
The system SHALL disable the "Sync Now" button and prevent manual sync execution when sync is disabled. When sync is re-enabled, the button SHALL become active again but SHALL NOT automatically trigger a sync.

#### Scenario: Sync Now button disabled when sync is off
- **WHEN** sync is disabled
- **THEN** the "Sync Now" button is visually disabled and does not respond to taps

#### Scenario: Sync Now button re-enabled when sync is turned on
- **WHEN** sync is re-enabled
- **THEN** the "Sync Now" button becomes active but no sync is triggered automatically

#### Scenario: Manual sync proceeds when sync is enabled
- **WHEN** the user presses "Sync Now" and sync is enabled
- **THEN** a full sync cycle executes normally

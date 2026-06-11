# Dry Run Sync

## Purpose

Preview what a sync cycle would do — which source events would be synced, skipped, updated, or deleted — without modifying any calendar data or mapping records.

## Requirements

### Requirement: Run dry run sync
The system SHALL execute a dry run sync using the same classification logic as the real sync engine (`SyncEngine`). The classification phase SHALL query source events and the mapping table, compare against target events where applicable, and produce a `SyncPlan` — without creating, updating, or deleting any calendar events or mapping database entries. The dry run SHALL classify each source event and each orphaned mapping into one of four categories: would-be-synced, would-be-skipped, would-be-updated, or would-be-deleted.

#### Scenario: Dry run with only new events
- **WHEN** the source calendar has 3 events and none are in the mapping table
- **THEN** the system returns 3 would-be-synced events, 0 would-be-skipped, and 0 would-be-deleted

#### Scenario: Dry run with mixed state
- **WHEN** the source calendar has 5 events and 2 are already mapped
- **THEN** the system returns 3 would-be-synced, 2 would-be-skipped, and 0 would-be-deleted

#### Scenario: Dry run with orphaned mappings
- **WHEN** the mapping table has an entry for a source event that no longer exists in the source calendar
- **THEN** the system returns that mapping as would-be-deleted

#### Scenario: Dry run makes no changes
- **WHEN** a dry run completes
- **THEN** no calendar events are created, updated, or deleted, and no mapping database rows are inserted or removed

### Requirement: Show projected target events
For each source event classified as would-be-synced, the system SHALL provide a preview showing what the target event would look like: title equal to the user's configured sync name, description equal to the source event's original title, and start/end times matching the source event.

#### Scenario: Projected event reflects user configuration
- **WHEN** the user has configured "Busy" as the sync name and a source event titled "Doctor Appointment" at 2pm–3pm would be synced
- **THEN** the projected event has title "Busy", description "Doctor Appointment", start 2pm, end 3pm

#### Scenario: Projected event uses empty sync name
- **WHEN** the user has configured an empty sync name and a source event would be synced
- **THEN** the projected event has an empty title

### Requirement: Dry run screen navigation
The system SHALL provide a navigable screen that displays dry run results. The screen SHALL be accessible from the home page via a dedicated button. The screen SHALL show the timestamp of when the dry run was executed.

#### Scenario: Dry run screen accessible from home page
- **WHEN** the user is on the home page
- **THEN** a button or icon is visible that navigates to the dry run screen

#### Scenario: Dry run screen shows result timestamp
- **WHEN** a dry run completes
- **THEN** the screen displays the date and time when the dry run was executed

#### Scenario: Dry run screen empty state
- **WHEN** the user navigates to the dry run screen without having executed a dry run
- **THEN** the screen shows a prompt encouraging the user to run a dry run

### Requirement: Dry run available regardless of sync setting
The system SHALL allow execution of a dry run independently of the sync enabled setting. Since dry run is read-only and makes no calendar or database modifications, it SHALL remain accessible even when sync is disabled.

#### Scenario: Dry run available when sync is off
- **WHEN** sync is disabled
- **THEN** the dry run button is active and responds to taps

#### Scenario: Dry run available when sync is on
- **WHEN** sync is enabled
- **THEN** the dry run button is active and responds to taps

## ADDED Requirements

### Requirement: React to calendar changes via ContentObserver
The system SHALL register a native Android ContentObserver on `CalendarContract.Events.CONTENT_URI` that triggers the sync engine when the source calendar changes. The observer SHALL debounce rapid changes by waiting 5 seconds before enqueueing work, using `ExistingWorkPolicy.REPLACE` to batch multiple triggers into a single sync.

#### Scenario: New event triggers sync
- **WHEN** a new event is added to the source calendar
- **THEN** the ContentObserver fires, and within ~5 seconds the sync engine creates a corresponding event in the target calendar

#### Scenario: Rapid changes batched
- **WHEN** 5 events are added to the source calendar in quick succession
- **THEN** only one sync cycle executes, processing all 5 events together

#### Scenario: Observer re-registers on app start
- **WHEN** the user launches the app after a force-stop
- **THEN** the ContentObserver is re-registered and future calendar changes will trigger sync

### Requirement: Propagate deletions to target calendar
When a previously synced source event no longer appears in the source calendar, the system SHALL delete the corresponding target event and remove the mapping record.

#### Scenario: Source event deleted, target cleaned up
- **WHEN** a source event that was previously synced is deleted from the source calendar and a sync cycle runs
- **THEN** the target event is deleted and the mapping row is removed

#### Scenario: Target event already deleted manually
- **WHEN** a source event was deleted and the target event was already removed manually by the user
- **THEN** the delete operation completes without error and the mapping row is still cleaned up

#### Scenario: Unmapped source events are unaffected by deletion pass
- **WHEN** the sync cycle runs and a source event is absent but was never synced (no mapping exists)
- **THEN** no delete operation is attempted for that event

### Requirement: Periodic fallback sync
The system SHALL maintain a periodic background task (default every 60 minutes, configurable) as a safety net that runs the same sync logic. This catches any changes missed by the ContentObserver (e.g., after force-stop before app re-launch).

#### Scenario: Fallback runs after observer gap
- **WHEN** a calendar change occurred while the ContentObserver was not registered (after force-stop)
- **THEN** the periodic fallback detects and syncs the change within the configured interval

#### Scenario: Fallback disabled when interval is 0
- **WHEN** the sync interval is set to 0
- **THEN** neither the ContentObserver nor the periodic task are active

### Requirement: Background task is resilient
The system SHALL handle errors during any background sync path gracefully. Missing permissions, unconfigured settings, or plugin errors SHALL cause the task to skip silently without affecting future runs.

#### Scenario: Permissions revoked between syncs
- **WHEN** calendar permissions are revoked after the ContentObserver was registered but before the worker executes
- **THEN** the sync callback returns immediately without crashing or retrying

#### Scenario: Plugin throws unexpected error
- **WHEN** the calendar plugin throws an unexpected error during background sync
- **THEN** the error is caught and the worker completes successfully, allowing future triggers to run

### Requirement: Background sync coexists with manual sync
Manual "Sync Now" and background sync SHALL coexist without conflicts. Both use the same idempotent sync engine.

#### Scenario: Concurrent manual and background sync
- **WHEN** the user presses "Sync Now" while a background sync cycle is in progress
- **THEN** both operations complete independently — the mapping table's UNIQUE constraints prevent duplicates

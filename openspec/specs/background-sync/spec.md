# Background Sync

## Purpose

Automatically synchronize calendar events in the background using reactive ContentObserver (primary) and periodic WorkManager fallback, including delete propagation.

## Requirements

### Requirement: React to calendar changes via ContentObserver
The system SHALL register a native Android ContentObserver on `CalendarContract.Events.CONTENT_URI` that triggers the sync engine when the source calendar changes, provided sync is enabled. The observer SHALL be re-registered by a native WorkManager periodic task to survive process death. The observer SHALL debounce rapid changes by waiting 5 seconds before enqueueing work. When sync is disabled, the Dart-side callback SHALL exit immediately without invoking the sync engine.

#### Scenario: Observer survives process death
- **WHEN** Android kills the app process and later the WorkManager periodic task executes
- **THEN** the ContentObserver is re-registered and reactive sync resumes without requiring the user to open the app

#### Scenario: New event triggers sync
- **WHEN** a new event is added to the source calendar and sync is enabled
- **THEN** the ContentObserver fires, and within ~5 seconds the sync engine creates a corresponding event in the target calendar

#### Scenario: Observer fires but sync is disabled
- **WHEN** a new event is added to the source calendar and sync is disabled
- **THEN** the ContentObserver fires but the Dart callback exits without invoking the sync engine

#### Scenario: Rapid changes batched
- **WHEN** 5 events are added to the source calendar in quick succession
- **THEN** only one sync cycle executes, processing all 5 events together

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
The system SHALL maintain a periodic background task (default every 60 minutes, configurable) as a safety net that runs the same sync logic, provided sync is enabled. This catches any changes missed by the ContentObserver (e.g., after force-stop before app re-launch). When sync is disabled, the periodic callback SHALL exit immediately.

#### Scenario: Fallback runs after observer gap
- **WHEN** a calendar change occurred while the ContentObserver was not registered (after force-stop) and sync is enabled
- **THEN** the periodic fallback detects and syncs the change within the configured interval

#### Scenario: Fallback exits when sync is disabled
- **WHEN** the periodic fallback task fires and sync is disabled
- **THEN** the callback exits immediately without invoking the sync engine

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

### Requirement: Show notification on sync activity
The system SHALL display a local Android notification summarizing the results after each background sync cycle that produces changes (synced > 0 or deleted > 0). Silent syncs with no activity SHALL NOT produce a notification. Callbacks that exit early due to sync being disabled SHALL NOT produce a notification.

#### Scenario: Sync with new events shows notification
- **WHEN** a background sync cycle creates 2 new events and deletes 1 orphaned event
- **THEN** a notification appears with the summary "Synced: 2, Deleted: 1, Skipped: 0"

#### Scenario: Sync with only skipped events shows no notification
- **WHEN** a background sync cycle finds all source events are already synced (synced=0, deleted=0)
- **THEN** no notification is shown

#### Scenario: Silent skip shows no notification
- **WHEN** the background task skips because permissions are denied or settings are unconfigured
- **THEN** no notification is shown

#### Scenario: Sync with errors shows notification with error count
- **WHEN** a background sync cycle creates 1 event but fails to create 2 others
- **THEN** a notification appears with the summary "Synced: 1, Deleted: 0, Skipped: 0 + 2 errors"

#### Scenario: Callback exits due to disabled sync shows no notification
- **WHEN** a background sync callback fires but exits because sync is disabled
- **THEN** no notification is shown

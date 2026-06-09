## MODIFIED Requirements

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

### Requirement: Show notification on sync activity
The system SHALL display a local Android notification summarizing the results after each background sync cycle that produces changes (synced > 0 or deleted > 0). Silent syncs with no activity SHALL NOT produce a notification. Callbacks that exit early due to sync being disabled SHALL NOT produce a notification.

#### Scenario: Callback exits due to disabled sync shows no notification
- **WHEN** a background sync callback fires but exits because sync is disabled
- **THEN** no notification is shown

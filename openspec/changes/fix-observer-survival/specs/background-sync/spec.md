## MODIFIED Requirements

### Requirement: React to calendar changes via ContentObserver
The system SHALL register a native Android ContentObserver on `CalendarContract.Events.CONTENT_URI` that triggers the sync engine when the source calendar changes. The observer SHALL be re-registered by a native WorkManager periodic task to survive process death. The observer SHALL debounce rapid changes by waiting 5 seconds before enqueueing work.

#### Scenario: Observer survives process death
- **WHEN** Android kills the app process and later the WorkManager periodic task executes
- **THEN** the ContentObserver is re-registered and reactive sync resumes without requiring the user to open the app

#### Scenario: New event triggers sync
- **WHEN** a new event is added to the source calendar
- **THEN** the ContentObserver fires, and within ~5 seconds the sync engine creates a corresponding event in the target calendar

#### Scenario: Rapid changes batched
- **WHEN** 5 events are added to the source calendar in quick succession
- **THEN** only one sync cycle executes, processing all 5 events together

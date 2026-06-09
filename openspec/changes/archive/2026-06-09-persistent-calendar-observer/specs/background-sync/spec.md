## MODIFIED Requirements

### Requirement: React to calendar changes via ContentObserver
The system SHALL declare a native Android `JobService` with a `TriggerContentUri` on `CalendarContract.Events.CONTENT_URI` that triggers a one-off WorkManager sync task when calendar content changes. The JobService SHALL be managed by the Android system and SHALL NOT require app process to be alive to detect changes. The JobService SHALL use a 5-second trigger content update delay to coalesce rapid changes.

#### Scenario: Observer survives process death
- **WHEN** Android kills the app process and a calendar change occurs on the source calendar
- **THEN** the JobService is triggered by the system and enqueues a sync task within 5 seconds, without requiring the user to open the app

#### Scenario: New event triggers sync
- **WHEN** a new event is added to the source calendar
- **THEN** the JobService fires within 5 seconds, and the sync engine creates a corresponding event in the target calendar

#### Scenario: Rapid changes batched
- **WHEN** 5 events are added to the source calendar in quick succession
- **THEN** the JobService's 5-second trigger update delay coalesces them, and only one sync cycle executes, processing all 5 events together

## REMOVED Requirements

### Requirement: Periodic observer re-registration
**Reason**: Replaced by system-managed JobService that does not require re-registration.
**Migration**: Remove `ObserverRegistrationWorker.kt` and cancel any existing `observer_registration` periodic work. The JobService declaration in `AndroidManifest.xml` handles registration automatically.

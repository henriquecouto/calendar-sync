# Persistent Observer

## Purpose

TBD

## Requirements

### Requirement: Calendar change detection survives process death
The system SHALL use a native Android `JobService` with a `TriggerContentUri` on `CalendarContract.Events.CONTENT_URI` to detect calendar changes. The JobService SHALL be declared in `AndroidManifest.xml` with `android:permission="android.permission.READ_CALENDAR"`. The system SHALL NOT require the app process to be alive for changes to be detected.

#### Scenario: Change detected while app process is dead
- **WHEN** a calendar event is added, modified, or deleted while the app process is not running
- **THEN** the JobService is triggered by the system within 5 seconds of the content change

#### Scenario: Change detected while app is in foreground
- **WHEN** a calendar event is added, modified, or deleted while the app is in the foreground
- **THEN** the JobService is triggered by the system within 5 seconds of the content change

### Requirement: JobService enqueues sync work on content change
The system SHALL enqueue a one-off WorkManager task with tag `calendar_sync_reactive` and `ExistingWorkPolicy.REPLACE` from within the JobService's `onStartJob()` method. The JobService SHALL complete immediately after enqueuing work (return `false`).

#### Scenario: Single calendar change triggers one sync
- **WHEN** the JobService is triggered by a calendar content change
- **THEN** exactly one one-off WorkManager task is enqueued and the JobService finishes

#### Scenario: Rapid changes coalesce into one sync
- **WHEN** 5 calendar changes occur within 5 seconds
- **THEN** at most one sync task is pending (subsequent triggers use `ExistingWorkPolicy.REPLACE`)

### Requirement: No periodic observer re-registration needed
The system SHALL NOT require any periodic task to maintain calendar change detection. The JobService SHALL remain registered by virtue of its `AndroidManifest.xml` declaration, regardless of app process state.

#### Scenario: No periodic re-registration after process death
- **WHEN** the app process is killed and later restarted
- **THEN** no explicit observer re-registration is performed, and calendar changes are still detected via the JobService

# Background Sync

## Purpose

Automatically synchronize calendar events in the background using reactive ContentObserver (primary) and periodic WorkManager fallback, iterating over all enabled profiles.

## Requirements

### Requirement: React to calendar changes via ContentObserver
The system SHALL declare a native Android `JobService` with a `TriggerContentUri` on `CalendarContract.Events.CONTENT_URI` that triggers a one-off WorkManager sync task when calendar content changes. The triggered sync SHALL iterate over all enabled profiles and sync each one. The JobService SHALL be managed by the Android system and SHALL NOT require app process to be alive to detect changes. The JobService SHALL use a 5-second trigger content update delay to coalesce rapid changes.

#### Scenario: Observer survives process death
- **WHEN** Android kills the app process and a calendar change occurs on any source calendar
- **THEN** the JobService is triggered by the system and enqueues a sync task within 5 seconds, without requiring the user to open the app

#### Scenario: New event triggers sync for relevant profile
- **WHEN** a new event is added to a source calendar that belongs to an enabled profile
- **THEN** the JobService fires within 5 seconds, and the sync engine creates a corresponding event in the profile's target calendar

#### Scenario: Rapid changes batched
- **WHEN** 5 events are added to source calendars in quick succession
- **THEN** the JobService's 5-second trigger content update delay coalesces them, and only one sync cycle executes, processing all events for all enabled profiles together

### Requirement: Propagate deletions to target calendar
When a previously synced source event no longer appears in the source calendar, the system SHALL delete the corresponding target event and remove the mapping record. This SHALL be scoped to the correct profile via profile ID on the mapping.

#### Scenario: Source event deleted, target cleaned up for correct profile
- **WHEN** a source event that was previously synced for profile "P1" is deleted from the source calendar and a sync cycle runs for profile "P1"
- **THEN** the target event is deleted and the mapping row for profile "P1" is removed
- **AND** mappings for the same event under different profiles are unaffected

### Requirement: Periodic fallback sync
The system SHALL maintain a single periodic background task as a safety net. When the task fires, it SHALL iterate over all enabled profiles and run the sync engine for each, provided each profile has the required configuration and permissions. The task interval SHALL be the minimum interval among all enabled profiles. When no profiles are enabled, the periodic task SHALL be cancelled. This catches any changes missed by the ContentObserver.

#### Scenario: Fallback syncs all enabled profiles
- **WHEN** the periodic task fires and 3 profiles are enabled
- **THEN** all 3 profiles SHALL be synced sequentially

#### Scenario: Fallback skips disabled profiles
- **WHEN** the periodic task fires and 1 of 3 profiles is disabled
- **THEN** only the 2 enabled profiles SHALL be synced

#### Scenario: Fallback exits when all profiles disabled
- **WHEN** the periodic fallback task fires and no profiles are enabled
- **THEN** the callback exits immediately without invoking the sync engine

#### Scenario: Fallback skips profile with missing configuration
- **WHEN** the periodic task fires and a profile has no source calendar configured
- **THEN** that profile SHALL be skipped without error and remaining profiles SHALL still be synced

#### Scenario: Fallback skips profile whose calendar was deleted
- **WHEN** the periodic task fires and a profile's source or target calendar no longer exists on the device (account removed, app uninstalled)
- **THEN** that profile SHALL be skipped silently without error
- **AND** the status table SHALL NOT log an error for that profile
- **AND** remaining profiles SHALL still be synced

### Requirement: Background task is resilient
The system SHALL handle errors during any background sync path gracefully. An error in one profile's sync SHALL NOT prevent other profiles from syncing. Missing permissions, unconfigured settings, deleted calendars, or plugin errors for a specific profile SHALL cause that profile to be skipped silently without affecting other profiles or future runs.

#### Scenario: One profile fails, others succeed
- **WHEN** the background task syncs 3 profiles and profile 2 throws an unexpected error
- **THEN** profiles 1 and 3 SHALL complete their sync normally
- **AND** profile 2's error SHALL be logged to the status table with the appropriate profile ID and error count

#### Scenario: Permissions revoked between syncs
- **WHEN** calendar permissions are revoked after the ContentObserver was registered but before the worker executes
- **THEN** the sync callback returns immediately without crashing or retrying

### Requirement: Background sync coexists with manual sync
Manual "Sync All" and background sync SHALL coexist without conflicts. Both use the same idempotent sync engine.

#### Scenario: Concurrent manual and background sync
- **WHEN** the user presses "Sync All" while a background sync cycle is in progress
- **THEN** both operations complete independently — the mapping table's per-profile UNIQUE constraints prevent duplicates

### Requirement: Show notification on sync activity
The system SHALL display a local Android "Syncing calendars..." ongoing notification when a reactive background sync is triggered by a calendar change. The notification SHALL be dismissed when the sync completes for all profiles. Sync results SHALL NOT appear in the notification — users view results in the sync history screen. Periodic fallback syncs SHALL NOT display a notification. The progress notification SHALL NOT appear for sync skipped due to all profiles disabled, missing permissions, or all profiles unconfigured.

#### Scenario: Reactive sync shows progress notification
- **WHEN** the CalendarSyncJobService detects a calendar change
- **THEN** an ongoing "Syncing calendars..." notification appears immediately

#### Scenario: Notification dismissed on sync completion
- **WHEN** the background sync completes for all profiles (signal written to SharedPreferences)
- **THEN** the progress notification is dismissed

#### Scenario: No notification for skipped sync
- **WHEN** the background task skips because all profiles are disabled, permissions denied, or all profiles unconfigured
- **THEN** no notification is shown

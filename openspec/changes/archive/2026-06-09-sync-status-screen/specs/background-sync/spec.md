## MODIFIED Requirements

### Requirement: Show notification on sync activity
The system SHALL display a local Android "Syncing calendars..." ongoing notification when a reactive background sync is triggered by a calendar change. The notification SHALL be dismissed when the sync completes. Sync results SHALL NOT appear in the notification — users view results in the sync history screen. Periodic fallback syncs that produce no changes SHALL NOT display a notification. The progress notification SHALL NOT appear for sync skipped due to disabled toggle, missing permissions, or unconfigured settings.

#### Scenario: Reactive sync shows progress notification
- **WHEN** the CalendarSyncJobService detects a calendar change
- **THEN** an ongoing "Syncing calendars..." notification appears immediately

#### Scenario: Notification dismissed on sync completion
- **WHEN** the background sync completes (signal written to SharedPreferences)
- **THEN** the progress notification is dismissed

#### Scenario: No notification for skipped sync
- **WHEN** the background task skips because sync disabled, permissions denied, or settings unconfigured
- **THEN** no notification is shown

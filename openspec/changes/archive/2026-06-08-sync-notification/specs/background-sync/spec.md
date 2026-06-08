## ADDED Requirements

### Requirement: Show notification on sync activity
The system SHALL display a local Android notification summarizing the results after each background sync cycle that produces changes (synced > 0 or deleted > 0). Silent syncs with no activity SHALL NOT produce a notification.

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

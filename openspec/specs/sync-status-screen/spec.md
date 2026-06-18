# Sync Status Screen

## Purpose

Provide a persistent per-profile history of sync results visible from the home page. Shows timestamp and counts for the last 20 sync cycles per profile with profile filtering.

## Requirements

### Requirement: Sync results are persisted to SQLite history
The system SHALL store each sync result as a row in a `sync_status` table within the existing `calendar_sync.db` SQLite database. Each row SHALL include a profile_id, timestamp, synced count, deleted count, skipped count, updated count, and error count. The table SHALL be capped at 20 rows per profile, deleting the oldest row for that profile when the limit is exceeded.

#### Scenario: Background sync appends to history
- **WHEN** a background sync (reactive or periodic) completes for a profile
- **THEN** a new row with profile ID, timestamp, and counts is inserted into the `sync_status` table

#### Scenario: History is capped at 20 per profile
- **WHEN** the `sync_status` table reaches 20 rows for a specific profile and a new sync completes for that profile
- **THEN** the oldest row for that profile is deleted and the new row is inserted

#### Scenario: Manual sync appends to history
- **WHEN** the user taps "Sync All" and a profile's sync completes
- **THEN** a new row with the profile ID is inserted into the same `sync_status` table

#### Scenario: Skipped sync is also logged
- **WHEN** a sync cycle for a profile completes with zero changes
- **THEN** a row is still inserted with profile ID, synced=0, updated=0, deleted=0, skipped=0, errors=0

#### Scenario: Sync with errors is logged per profile
- **WHEN** a sync cycle for a profile completes with some events that failed
- **THEN** a row is inserted with the profile ID and the error count reflecting the failures alongside any successful counts

### Requirement: Sync status screen displays recent history
The system SHALL provide a screen accessible from the home page that displays the recent sync history entries from the SQLite database. Entries SHALL be shown newest-first in a scrollable list. Each row SHALL display the profile name (or source→target summary), the timestamp (formatted datetime), and the same summary text format used in notifications (e.g., "Synced: 2, Deleted: 1, Skipped: 0"). Rows with errors SHALL indicate the error count. A filter control SHALL allow viewing history for a specific profile or all profiles.

#### Scenario: User navigates to status screen
- **WHEN** the user taps the history icon in the home page AppBar
- **THEN** the sync status screen opens showing the latest 20 entries from the database across all profiles

#### Scenario: Filter by profile
- **WHEN** the user selects a specific profile from the filter dropdown
- **THEN** only status entries for that profile SHALL be displayed

#### Scenario: Filter shows all profiles
- **WHEN** the user selects "All profiles" in the filter dropdown
- **THEN** status entries for all profiles SHALL be displayed, with each entry showing which profile it belongs to

#### Scenario: Empty state
- **WHEN** no sync results have been recorded yet
- **THEN** the screen displays a message indicating no sync history is available

#### Scenario: Refresh updates the list
- **WHEN** the user refreshes the status screen (pull-to-refresh or refresh button)
- **THEN** the list reloads from the database showing any new entries, respecting the current profile filter

### Requirement: Status entries include profile identification
Each status row SHALL include a `profile_id` column. When displaying status entries, the row SHALL show the profile's name (user-defined or auto-generated like "Personal → Work") so the user can identify which profile produced the result.

#### Scenario: Status row identifies profile
- **WHEN** a status entry for profile "abc-123" named "Work Sync" is displayed
- **THEN** the entry SHALL show the profile name "Work Sync"

#### Scenario: Existing rows without profile ID are handled
- **WHEN** the database contains legacy status rows without a `profile_id`
- **THEN** those rows SHALL display "Unknown profile" or a similar placeholder label

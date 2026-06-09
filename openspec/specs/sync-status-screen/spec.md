# Sync Status Screen

## Purpose

Provide a persistent history of sync results visible from the home page, replacing the single transient status line. Shows timestamp and counts (synced, deleted, skipped, errors) for the last 20 sync cycles.

## Requirements

### Requirement: Sync results are persisted to SQLite history
The system SHALL store each sync result as a row in a `sync_status` table within the existing `calendar_sync.db` SQLite database. Each row SHALL include a timestamp, synced count, deleted count, skipped count, and error count. The table SHALL be capped at 20 rows, deleting the oldest row when the limit is exceeded.

#### Scenario: Background sync appends to history
- **WHEN** a background sync (reactive or periodic) completes with results
- **THEN** a new row with timestamp and counts is inserted into the `sync_status` table

#### Scenario: History is capped at 20
- **WHEN** the `sync_status` table reaches 20 rows and a new sync completes
- **THEN** the oldest row is deleted and the new row is inserted

#### Scenario: Manual sync appends to history
- **WHEN** the user taps "Sync Now" and the sync completes
- **THEN** a new row is inserted into the same `sync_status` table

#### Scenario: Skipped sync is also logged
- **WHEN** a sync cycle completes with zero changes (all events already synced, or sync disabled, or permissions missing)
- **THEN** a row is still inserted with synced=0, deleted=0, skipped=0 and appropriate error count

#### Scenario: Sync with errors is logged
- **WHEN** a sync cycle completes with some events that failed to create or delete
- **THEN** a row is inserted with the error count reflecting the failures alongside any successful synced/deleted counts

### Requirement: Sync status screen displays recent history
The system SHALL provide a screen accessible from the home page that displays the recent sync history entries from the SQLite database. Entries SHALL be shown newest-first in a scrollable list. Each row SHALL display the timestamp (formatted datetime) and the same summary text format used in notifications (e.g., "Synced: 2, Deleted: 1, Skipped: 0"). Rows with errors SHALL indicate the error count.

#### Scenario: User navigates to status screen
- **WHEN** the user taps the history icon in the home page AppBar
- **THEN** the sync status screen opens showing the latest 20 entries from the database

#### Scenario: Empty state
- **WHEN** no sync results have been recorded yet
- **THEN** the screen displays a message indicating no sync history is available

#### Scenario: Refresh updates the list
- **WHEN** the user refreshes the status screen (pull-to-refresh or refresh button)
- **THEN** the list reloads from the database showing any new entries

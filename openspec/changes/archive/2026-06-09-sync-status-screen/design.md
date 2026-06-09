## Context

The app's `HomePage` displays a single transient status line after manual sync. Background sync results are written to a single `SharedPreferences` key (`pending_sync_notification`) which is overwritten on each sync and only consumed by the native notification display. There is no persistent history visible to the user.

## Goals / Non-Goals

**Goals:**
- Show the N most recent sync results (default N=20) with timestamps
- Accessible from the home page via a navigation action (icon button in AppBar or similar)
- Each row shows the same summary as the notification (synced/deleted/skipped/errors) plus datetime
- Entries come from both manual and background syncs
- Failed and skipped syncs are also logged (not just successful ones)
- Scrollable list, newest first

**Non-Goals:**
- Per-event detail (only summary counts)
- Export/share functionality
- Filtering or search
- Sync status from before this change is deployed (no migration of old data)

## Decisions

### Decision 1: Store history in SQLite (`calendar_sync.db`)

**Chosen:** Add a `sync_status` table to the existing `calendar_sync.db` database. The table has columns: `id`, `timestamp`, `synced`, `deleted`, `skipped`, `errors`. Cap at 20 rows by deleting oldest when limit exceeded.

**Rationale:**
- `sqflite` is already a dependency; the database file already exists
- Avoids JSON serialization gymnastics in `shared_preferences`
- Queries are simpler (ORDER BY id DESC LIMIT 20)
- The existing `MappingDatabase` class is extended; same database path, same connection pattern
- Database version bump from 1 → 2 with `onUpgrade` migration

**Alternative considered:** SharedPreferences JSON list.
- Rejected in favor of SQLite for consistency with existing data layer.

### Decision 2: Notification becomes progress-only, dismissed on completion

**Chosen:** When the `CalendarSyncJobService` detects a calendar change, it shows an ongoing "Syncing..." notification immediately. When sync completes (signaled by `pending_sync_notification` key in SharedPreferences), the notification is dismissed. No results are shown in the notification — users view results in the history screen.

**Rationale:**
- The `pending_sync_notification` key acts as a simple "done" signal, not a result carrier
- Avoids duplicate information (notification + history screen showing same data)
- The ongoing notification provides feedback that background work is happening
- The `CalendarSyncJobService` continues to use SharedPreferences as a bridge (can't query SQLite from Kotlin)

### Decision 3: Navigation via AppBar action icon

**Chosen:** Add a history icon button in the home page's AppBar that navigates to `SyncStatusScreen`. Simple `Navigator.push()`.

**Rationale:**
- Minimal UI footprint
- Consistent with Material Design patterns

### Decision 4: Log all sync outcomes (not just successful ones)

**Chosen:** The `callbackDispatcher` appends an entry regardless of result — even if synced/deleted/skipped are all zero, or if the sync was skipped due to disabled toggle, missing permissions, etc.

**Rationale:**
- Users need to know when nothing happened too (confirms the system is alive)
- Helps debug "why didn't my calendar change sync?"

## Risks / Trade-offs

- **[Risk] Database migration on upgrade**: Adding a new table requires `onUpgrade` with version bump. → **Mitigation**: Simple migration — just CREATE TABLE IF NOT EXISTS. No data migration needed (the mapping table is preserved).
- **[Trade-off] No real-time update on status screen**: The list doesn't auto-refresh while viewing. → **Mitigation**: Refresh button on the status screen that reloads from database.

## Why

The app currently supports a single source→target calendar pair, stored as flat global settings. Users who need to sync multiple calendar pairs (e.g., personal→work and work→personal, or multiple project calendars) must manually reconfigure the app each time. This change allows users to create, manage, and run multiple sync profiles simultaneously, each with independent source/target calendars, event names, intervals, and enable states.

## What Changes

- **BREAKING**: Replace flat `SharedPreferences` settings with a profile-based persistence model (SQLite `sync_profiles` table), migrating existing single-profile configuration to a default profile on first launch
- Add profile CRUD operations (create, read, update, delete) via a new `ProfileService`
- Add `profile_id` column to `sync_mappings` and `sync_status` tables; update the UNIQUE constraint on `sync_mappings` to include `profile_id`
- Update `SyncEngine` to accept and record a `profileId` for all sync operations
- Update the background sync task to iterate over all enabled profiles and sync each one
- Update the Dashboard to display a scrollable list of profile cards with per-profile sync buttons and a "Sync All" action
- Update the `ProfileConfigScreen` to support create, edit, and delete operations using profile ID
- Add profile filtering to the sync status history screen
- Dry-run screen updates to support per-profile execution

## Capabilities

### New Capabilities

- `sync-profiles`: Manage multiple synchronization profiles. Each profile has its own source calendar, target calendar, event name, sync interval, and enabled state. Profiles are persisted in a local SQLite table and survive app restarts. Users can create, edit, enable/disable, and delete profiles. The mapping table and status history are scoped per-profile to avoid cross-contamination.

### Modified Capabilities

- `app-settings`: Settings (source calendar, target calendar, event name, interval, enabled) are now scoped per-profile instead of being global. The single global configuration is migrated to a default profile on upgrade. The "sync enabled" toggle moves from global to per-profile.
- `event-sync`: The sync mapping table (`sync_mappings`) gains a `profile_id` column. The UNIQUE constraint expands to `(profile_id, source_calendar_id, source_event_id)`. All mapping queries filter by `profile_id`. The sync engine accepts `profileId` as a parameter.
- `background-sync`: The background task iterates over all enabled profiles and runs a sync cycle for each. The periodic fallback and reactive ContentObserver both process all enabled profiles.
- `sync-status-screen`: The `sync_status` table gains a `profile_id` column. The status screen adds profile filtering so users can view history scoped to a specific profile.

## Impact

- **Data layer**: New `sync_profiles` table in `calendar_sync.db`; schema migration (v3→v4) for `sync_mappings` and `sync_status` to add `profile_id` columns
- **Settings**: `SettingsService` replaced by `ProfileService`; `SharedPreferences` keys either deprecated or used only for the migration flag
- **UI**: `DashboardScreen`, `ProfileConfigScreen`, `ProfileCard`, `SyncStatusScreen`, and `DryRunScreen` updated for multi-profile awareness
- **Background**: `sync_task.dart` and native `JobService` updated to iterate profiles
- **Workmanager**: Interval handling changes — either a single task iterating all profiles or per-profile tasks (depends on design decision)

## Context

The app currently stores sync configuration as five flat `SharedPreferences` keys supporting exactly one source→target calendar pair. The UI already uses a list-based layout with "profile" terminology, but the data layer has no notion of multiple profiles. The sync engine is stateless (all config passed as parameters), which makes it well-suited for multi-profile without internal refactoring. The main work is in the data layer, UI orchestration, and background task coordination.

## Goals / Non-Goals

**Goals:**
- Allow users to create and manage multiple named sync profiles, each with independent source calendar, target calendar, event name, interval, and enabled state
- Maintain per-profile sync mappings so profiles sharing the same source calendar do not collide
- Log sync status per-profile so users can see which profile produced which results
- Background sync (reactive + periodic) iterates all enabled profiles
- Migrate existing single-profile configuration seamlessly on upgrade

**Non-Goals:**
- Profile syncing across devices (profile data stays local)
- Cross-profile event linking (events from profile A sync to profile B)
- Different mapping strategies per profile (same engine, same rules)
- Per-profile permission handling (calendar permissions remain device-wide)

## Decisions

### Decision 1: SQLite for profile storage (not SharedPreferences/JSON)

**Choice**: Store profiles in a new `sync_profiles` table in the existing `calendar_sync.db` SQLite database.

**Rationale**: The app already uses SQLite for mappings and status history. Adding a profiles table keeps all sync data in one place, provides typed columns, transactional integrity, and avoids the complexity of encoding lists in SharedPreferences strings. The existing `MappingDatabase` class can be expanded to handle profile CRUD.

**Alternatives considered**:
- *JSON string in SharedPreferences*: Simpler to implement but fragile — a single write corruption loses all profiles. No queryability, no migration safety.
- *Separate SQLite database*: Unnecessary indirection given the existing database already manages sync state.

### Decision 2: UUID string profile IDs (not auto-increment integers)

**Choice**: Use UUID v4 strings as profile identifiers.

**Rationale**: Auto-increment integers would be simpler but create ambiguity if profiles are ever exported/imported or referenced across database tables with different auto-increment sequences. UUIDs are self-contained and eliminate collision risk. The overhead is negligible for a small number of profiles.

**Alternatives considered**:
- *Auto-increment integers*: Simpler but fragile across future import/export features. Already ruled out by proposal's emphasis on independence.

### Decision 3: Single WorkManager task iterating profiles (not per-profile tasks)

**Choice**: Maintain a single periodic `WorkManager` task. When it fires, iterate all enabled profiles and sync each. The task interval is the minimum of all enabled profiles' configured intervals.

**Rationale**: `WorkManager` periodic tasks have a minimum 15-minute interval on Android. If a user has 3 profiles with intervals 15, 30, and 60 minutes, running at 15 minutes covers all of them. Per-profile tasks would risk hitting Android's task limits and increase battery usage. The reactive `ContentObserver` remains the primary trigger; the periodic task is a fallback.

**Alternatives considered**:
- *Per-profile periodic tasks*: Would honor each profile's interval exactly but creates task management complexity (register/unregister on CRUD), risks tripping Android's background task limits, and is overkill for a fallback path that the ContentObserver already covers in real time.

### Decision 4: Migration via SharedPreferences flag

**Choice**: On first launch after upgrade, check for the old `source_calendar_id` SharedPreferences key. If present and no `sync_profiles` table exists (or it's empty), create a default profile from the old settings, then clear the old keys. Mark migration as done via a `profile_migration_done` SharedPreferences boolean.

**Rationale**: The existing user base (if any) should not lose their configuration. A one-time migration on app start is simple and self-contained. The flag prevents re-migration if the user clears the profiles table.

### Decision 5: Profile-aware mapping queries (not separate databases)

**Choice**: Add `profile_id TEXT NOT NULL` to `sync_mappings` and update the UNIQUE constraint to `(profile_id, source_calendar_id, source_event_id)`. All queries gain a `WHERE profile_id = ?` clause.

**Rationale**: A single-source event may legitimately be synced by two different profiles (e.g., Profile A syncs Calendar 1→Calendar 2, Profile B syncs Calendar 1→Calendar 3). Without `profile_id`, the UNIQUE constraint would prevent the second profile from syncing the same source event. Adding `profile_id` scopes the mapping to a specific profile.

### Decision 6: Profile filtering on status history

**Choice**: Add `profile_id TEXT` to `sync_status` table. New status entries always include `profile_id`. The status screen offers a dropdown to filter by profile, defaulting to "All profiles".

**Rationale**: Users need to know which profile produced which result, especially when debugging. The dropdown keeps the screen clean while supporting filtering.

## Risks / Trade-offs

- **[Schema migration failure]**: If the v3→v4 migration fails (e.g., adding columns to populated tables), the app could crash on startup. → Mitigation: Wrap migration in try/catch with `onUpgrade`; use `ALTER TABLE ADD COLUMN` (safe in SQLite); add defaults for existing rows.
- **[Profile UUID collision]**: Theoretically possible but astronomically unlikely with UUID v4. → Mitigation: Use the `uuid` package with collision check on insert (UNIQUE constraint at DB level).
- **[Background sync timeout]**: Iterating N profiles in a single Workmanager task may exceed the 10-minute execution limit. → Mitigation: Realistic profile count is small (1-5). The ContentObserver path syncs a single profile reactively, not all.
- **[Old mappings become unowned]**: Existing mapping rows have no `profile_id`. After migration, they belong to no profile. → Mitigation: During v3→v4 migration, add `profile_id` with a DEFAULT value of the migrated default profile ID. If no migration is needed (fresh install), the column is NOT NULL from the start.

## Migration Plan

1. **Database schema v3→v4**: `onUpgrade` adds `profile_id TEXT` column to `sync_mappings` and `sync_status` with DEFAULT empty string for existing rows.
2. **Settings migration**: `main.dart` or an early initialization step checks for old `SharedPreferences` keys. If found and profiles table is empty, creates a default profile and sets the migration flag.
3. **Rollback**: Not explicitly supported. Users on the old version can restore from backup. No reverse migration path from profiles back to flat settings.

### Decision 7: User-defined profile name (mandatory, unique, with auto-generated fallback)

**Choice**: Each profile has a user-editable `name` field (TEXT NOT NULL). Names must be unique across all profiles. If the user leaves the name empty, the system auto-generates one from the selected calendars: `"Calendar A → Calendar B"`. The migrated default profile gets the name `"Default"`.

**Rationale**: Profiles are easier to identify by name than by raw calendar IDs, especially in the status history filter. Uniqueness prevents UI confusion (two cards with the same label). Auto-generated fallback ensures the field is never truly empty, keeping the data model clean.

**Alternatives considered**:
- *Name derived solely from calendar pair*: No user control. Two profiles syncing the same calendars in different directions would be indistinguishable.
- *Optional name (nullable)*: Complicates UI — every display site must handle null. Forcing a name (auto-generated if needed) is simpler.

### Decision 8: Global `sync_created_events` table to prevent sync loops

**Choice**: Add a `sync_created_events` table with columns `(calendar_id TEXT NOT NULL, event_id TEXT NOT NULL, UNIQUE(calendar_id, event_id))`. Every time the sync engine creates a target event, it inserts a row into this table. Before classifying any source event, the engine checks this table — if the event was created by sync (any profile), it is skipped. Rows are removed when the target event is deleted (either by orphan processing or profile deletion cascade).

**Rationale**: With bidirectional profiles (e.g., Work→Personal and Personal→Work), events created by one profile appear as source events for the inverse profile. Without a global marker, the inverse profile would sync them back, creating an infinite loop. The `sync_created_events` table is scoped globally (not per-profile) because an event created by any profile should be treated as synthetic by all profiles. It is separate from `sync_mappings` because a mapping links a specific source→target pair, while the created-events table marks the target event itself as synthetic regardless of which profile created it.

**Lifecycle**:
- **INSERT**: When `SyncEngine._execute()` successfully creates a target event
- **DELETE (orphan)**: When `_processOrphanMappings()` deletes a target event whose source is gone
- **DELETE (profile deletion)**: When a profile is deleted, all its mappings are removed. The corresponding target events are NOT deleted (they may be referenced by other mappings), but `sync_created_events` rows for those events are removed
- **DELETE (update path)**: When `_execute()` replaces a target event via create+delete, the old `sync_created_events` row is deleted and a new one is inserted for the replacement

**Alternatives considered**:
- *Marker in event description*: Pollutes user calendar data, fragile if user edits the event.
- *Block bidirectional pairs*: Too restrictive — the user's real use case is a fully-connected graph between 3+ calendars.
- *Cross-profile mapping lookup*: The engine would need to check all profiles' mappings, not just its own. Complex, slow, and breaks profile isolation.

## Migration Plan (updated)

1. **Database schema v3→v4**: `onUpgrade` adds `profile_id TEXT` column to `sync_mappings` and `sync_status` with DEFAULT empty string for existing rows. Creates the `sync_created_events` table.
2. **Settings migration**: `main.dart` or an early initialization step checks for old `SharedPreferences` keys. If found and profiles table is empty, creates a default profile and sets the migration flag.
3. **Rollback**: Not explicitly supported. Users on the old version can restore from backup. No reverse migration path from profiles back to flat settings.

### Decision 9: Missing calendar handling — warn, don't block

**Choice**: When a profile's source or target calendar no longer exists on the device, the dashboard card shows a warning indicator (e.g., orange icon, muted styling). During sync (manual or background), the profile is skipped silently without error. The user can edit the profile to select a new calendar, or delete the profile. The profile is NOT automatically deleted.

**Rationale**: Calendar providers can disappear (account removed, app uninstalled). The app should be resilient — skipping is safer than crashing or auto-deleting user configuration. The warning gives the user agency to fix or remove the profile.

**Alternatives considered**:
- *Auto-delete the profile*: Aggressive. User may re-add the calendar later and expect the profile to still work.
- *Throw an error during sync*: Pollutes the status history with noise, blocks other profiles from syncing.
- *Do nothing (silently fail)*: User has no visibility into why sync stopped working.

## Open Questions

*(none — all resolved)*

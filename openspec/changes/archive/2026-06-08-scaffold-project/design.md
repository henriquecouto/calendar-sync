## Context

The repository is empty. We need a Flutter project targeting Android, built via Gradle CLI. The app syncs events between local device calendars: when an event appears in a source calendar, a copy is created in a target calendar using a user-provided name. Duplicate detection relies on a local mapping table (source event/calendar ID -> target event/calendar ID).

## Goals / Non-Goals

**Goals:**
- Scaffold a working Flutter project with `flutter create` as baseline, customized for this app
- Add `device_calendar`, `sqflite`, and `permission_handler` dependencies
- Establish module boundaries with interfaces between concerns
- Implement the runtime permission request flow end-to-end
- Create the SQLite mapping table schema and a thin DAO layer
- Ensure `flutter analyze` passes clean and `flutter test` runs at least a smoke test

**Non-Goals:**
- Full sync engine implementation (only skeleton and mapping table)
- UI polish or final layout
- Background sync or scheduled jobs
- iOS or web targets

## Decisions

### Project scaffolding via `flutter create --platforms android`

Using the standard Flutter CLI generates the correct Gradle wrapper, `android/` manifest, and test harness. No manual Gradle tweaking. Keeps the CLI-only constraint satisfied.

### Module boundaries in `lib/`

| Directory | Responsibility |
|-----------|---------------|
| `lib/permissions/` | Check and request `READ_CALENDAR` / `WRITE_CALENDAR`. Exposes a single `PermissionGate` widget or service. |
| `lib/calendar/` | Thin wrapper around `device_calendar` plugin. Exposes `listCalendars()`, `listEvents(calendarId)`, `createEvent(calendarId, event)`. |
| `lib/sync/` | Sync engine and mapping table. Exposes `SyncEngine` that accepts a source/target calendar ID and user-defined event name. Internally queries mapping table, diffs source events, creates target events, and inserts new mappings. |
| `lib/settings/` | Persists user config (source calendar ID, target calendar ID, sync event name). Uses `shared_preferences` for simple key-value storage. |
| `lib/main.dart` | App entrypoint. MaterialApp with a basic widget tree. |

### Mapping table in SQLite via `sqflite`

Schema:
```sql
CREATE TABLE sync_mappings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  source_calendar_id TEXT NOT NULL,
  source_event_id TEXT NOT NULL,
  target_calendar_id TEXT NOT NULL,
  target_event_id TEXT NOT NULL,
  synced_at TEXT NOT NULL,
  UNIQUE(source_calendar_id, source_event_id)
);
```

Rationale: SQLite is shipped with Android, requires no server. `sqflite` is the standard Flutter SQLite plugin. The UNIQUE constraint on (source_calendar_id, source_event_id) prevents double-sync. We store both IDs from both calendars because IDs are per-provider (see AGENTS.md gotcha).

### Permissions via `permission_handler`

`device_calendar` requires runtime permissions. `permission_handler` is the most popular Flutter permission plugin and handles the Android `Manifest.permission` flow correctly. We use it to gate all calendar operations: the permission check runs on app start; if denied, the app shows a prompt; if permanently denied, the app directs the user to system settings.

### `shared_preferences` for app settings

Three settings keys: `source_calendar_id`, `target_calendar_id`, `sync_event_name`. Simple, no migration overhead. If settings grow complex later, we can migrate to SQLite or a typed store.

## Risks / Trade-offs

- [Risk] `device_calendar` may behave differently across Android versions and calendar providers (Google, Samsung, etc.) → Mitigation: Abstract behind `lib/calendar/` wrapper so the plugin can be replaced or patched without touching sync logic.
- [Risk] `sqflite` adds a native dependency and build complexity → Mitigation: It's the de facto standard; any replacement (drift, hive) has similar complexity.
- [Risk] Mapping table grows unbounded over time → Non-goal for scaffold; future change can add pruning/retention logic.
- [Risk] Event IDs can change if an event is modified (some providers regenerate IDs) → Mitigation: The mapping table records the synced state; a re-sync will detect the mapping gap and re-create.

## Open Questions

- Should the scaffold include a CI pipeline (GitHub Actions)? Deferred — not in scope for initial scaffold.
- What should the initial UI look like? Deferred — scaffold includes a minimal placeholder MaterialApp only.

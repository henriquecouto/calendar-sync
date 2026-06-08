## Why

The repository is empty. To build the calendar sync app, we need a Flutter project skeleton with the right dependencies, build configuration, and foundational module boundaries. Without scaffolding, every feature work will fight against missing infrastructure.

## What Changes

- Create a Flutter project targeting Android with Gradle CLI build support
- Add `device_calendar` plugin as the sole calendar access dependency
- Establish `lib/` module boundaries: permissions, calendar data access, sync engine, settings, and UI entrypoint
- Implement runtime permission request flow for `READ_CALENDAR` / `WRITE_CALENDAR`
- Wire up a local mapping table (SQLite via `sqflite`) for sync-meta persistence
- Set up `flutter analyze` and `flutter test` as CI-able quality gates

## Capabilities

### New Capabilities

- `calendar-access`: Retrieve events from a source calendar and create events in a target calendar. Exposes per-provider calendar ID and event ID awareness.
- `event-sync`: Core sync logic that reads the mapping table to detect already-synced events, creates target events with a user-provided name, and records new mappings.
- `app-settings`: Persist user-configurable values (sync name, source calendar, target calendar) and expose them to the sync engine.
- `permission-handling`: Request and verify `READ_CALENDAR` / `WRITE_CALENDAR` permissions at runtime before any calendar operation.

### Modified Capabilities

None — this is a greenfield scaffold.

## Impact

- New project under `lib/` (Dart), `android/` (platform), and `test/`
- One new dependency: `device_calendar` (plugin), plus `sqflite` for the mapping table
- Gradle configuration in `android/` for CLI-only builds (no Android Studio assumptions)

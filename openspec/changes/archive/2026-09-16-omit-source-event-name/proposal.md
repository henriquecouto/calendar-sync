## Why

When users sync a personal calendar to a work calendar (e.g., to block out busy time), the target event's description currently embeds the original source event title in the first line, above the sync marker. This leaks personal information (e.g., "Doctor Appointment") into the work calendar's description field, which other people may be able to see. Users need a privacy mode that omits the source event title from the target event's description while keeping all other sync behavior intact (target event is still created, still marked with the sync marker, and copy-description / copy-location toggles still work as before).

## What Changes

- New profile-level toggle `omitSourceTitle` (default `false` — preserves current behavior) controls whether the source event's title appears as plaintext in the target event's description
- When `omitSourceTitle` is `true`, the source title is replaced by a **full SHA256 fingerprint** of the title (64 hex characters) in the target description — the description becomes `<sha256>\n---\n🔃 Automatically created by CalSync` (plus the optional prepended source description when `copyDescription` is `true`). The fingerprint is one-way (non-reversible) but deterministic, which lets the sync engine still detect when the title has changed without ever revealing the title in the work calendar
- `SyncEngine.buildDescription()` and the description-formatting logic in `runSync` / `runDryRun` gain the new flag and compute the SHA256 fingerprint when needed
- Change-detection in `_classifySingle` switches between two strategies based on `omitSourceTitle`:
  - `false` (default): existing `description.contains(event.title)` check (unchanged)
  - `true`: `description.contains(sha256(event.title))` — robust against calendar-provider HTML wrapping and substring collisions (the hash is ASCII and effectively unique)
- Profile form Advanced section gains a new "Omit source event title" toggle
- `sync_profiles` table gains a new `omit_source_title` column with a database migration (version 7 → 8)
- New dependency: `package:crypto` for SHA256

## Capabilities

### New Capabilities

- `omit-source-title`: Privacy-mode toggle on each sync profile that prevents the source event's original title from appearing in the target event's description, replacing it with a non-reversible SHA256 fingerprint so the sync engine can still detect title changes. Preserves all other sync behavior (sync marker, copy-description / copy-location toggles).

### Modified Capabilities

- `event-sync`: The "Create synced event with user-provided name" requirement must honor the new `omitSourceTitle` flag when building the target event's description (replacing the title line with its SHA256 fingerprint). The "Detect already-synced events" change-detection must use the SHA256-based check when `omitSourceTitle` is true and the title-based check otherwise.
- `sync-profiles`: The profile data model gains an `omitSourceTitle` field defaulting to `false`. The profile form's Advanced section gains the new toggle. The `sync_profiles` table schema and migrations are updated.
- `copy-event-description`: The "Copy description" behavior must compose correctly with `omitSourceTitle` — when both are enabled, the source description is still prepended, but the source title line that follows is replaced by its SHA256 fingerprint.

## Impact

- Affected files: `lib/sync/sync_engine.dart` (extend `buildDescription` to compute SHA256 when `omitSourceTitle`; new change-detection branch in `_classifySingle`; pass flag through `runSync` / `runDryRun`), `lib/sync/database_provider.dart` (new column + migration v8), `lib/settings/profile_service.dart` (new field on `SyncProfile` + create/update/read plumbing), `lib/screens/profile_config_screen.dart` (new toggle in Advanced section), `lib/screens/dashboard_screen.dart`, `lib/background/sync_task.dart`, `lib/sync/dry_run_screen.dart` (pass flag), tests under `test/`
- New dependency: `crypto: ^3.0.0` (Dart team, pure Dart, F-Droid compatible) added to `pubspec.yaml` only — shared deps are not duplicated in `pubspec_gplay.yaml` (which contains only gplay-only deps like `in_app_purchase` and `url_launcher`)
- Database schema version bumps 7 → 8; existing rows default `omit_source_title = 0` (off, preserving current behavior)
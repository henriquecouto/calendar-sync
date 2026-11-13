# Proposal: Sync recurring events as independent instances

## Why

Today a recurring source event is mirrored as a single recurring series in the target calendar, copying the recurrence rule. Per-occurrence exceptions — an instance moved to a different date or deleted — are not reflected in the target, because the master series has no knowledge of them. Users want to edit individual occurrences in the target calendar, which is only possible if each occurrence exists as an independent event.

## What Changes

- **BREAKING**: Recurring source events no longer create recurring target events. Each occurrence listed in the sync window becomes an independent, non-recurring target event with its own mapping.
- Per-profile sync window setting (1, 3, 6, or 12 months) replaces the hardcoded 30-day listing window. The window is chosen in the profile form and persisted per profile.
- The mapping table becomes one-to-many: rows are keyed by `(source_event_id, source_instance_id)` instead of `source_event_id` alone.
- `canonical_time` is no longer stored or used for recurring events; per-occurrence time comparison is direct.
- **Lazy migration**: on the first sync after upgrade, legacy mappings for recurring series (single mapping → recurring target event) are detected and replaced: the old recurring target event is deleted and occurrences are re-created as independent events.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `event-sync`: recurring event handling changes from "copy recurrence rule to target" to "expand each occurrence into an independent target event"; mapping rows gain `source_instance_id`; orphan detection becomes per-occurrence; the sync cycle lists events using the profile's configured window instead of a fixed 30 days.
- `sync-profiles`: profile data model gains a sync window field (1/3/6/12 months, default 1 month); the profile form gains a window selector.

## Impact

- `lib/sync/sync_engine.dart` — classification, orphan processing, and execution for per-instance sync
- `lib/calendar/calendar_service.dart` — `listEvents` window parameter
- `lib/sync/mapping_database.dart`, `lib/sync/database_provider.dart` — schema v9 (`source_instance_id`, `sync_window_days`) and migration
- `lib/settings/profile_service.dart` — sync window field
- `lib/screens/profile_config_screen.dart` — window selector UI
- `test/sync_engine_test.dart`, `test/mapping_database_test.dart`, `test/profile_service_test.dart` — new/updated tests
- `AGENTS.md` — mapping table documented as one-to-many

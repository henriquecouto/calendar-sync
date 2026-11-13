# Tasks

## 1. Database schema v9

- [x] 1.1 Bump `DatabaseProvider` version to 9 and add `onUpgrade` migration: rebuild `sync_mappings` with nullable `source_instance_id TEXT` and `UNIQUE(profile_id, source_calendar_id, source_event_id, source_instance_id)` (v4 table-rebuild pattern)
- [x] 1.2 Add `sync_window_days INTEGER NOT NULL DEFAULT 30` to `sync_profiles` (ALTER TABLE, v7/v8 pattern)
- [x] 1.3 Update `onCreate` to create the new schema directly for fresh installs
- [x] 1.4 Add `source_instance_id` to `MappingDatabase.insertMapping` and to `isEventSynced` lookups

## 2. Per-occurrence classification in sync engine

- [x] 2.1 Remove the `eventId != instanceId` special-case branch in `_classify`; classify every listed event directly by `(eventId, instanceId)`
- [x] 2.2 Pass `source_instance_id` through `isEventSynced`, `_classifySingle`, and `insertMapping` (null for non-recurring)
- [x] 2.3 Remove `canonical_time` computation and comparison; compare occurrence `startDate`/`endDate` millis directly
- [x] 2.4 Stop passing `recurrenceRule` to `createEvent` in `_execute` (create and update paths); remove the parameter from `CalendarService.createEvent`
- [x] 2.5 Rework `_processOrphanMappings`: per-occurrence orphan resolution (missing target → cleanup; target end > 7 days past → keep; `source_instance_id` set → master check via `getEvent` → delete on master-gone or occurrence-moved; `source_instance_id` null → existing re-classify flow)

## 3. Lazy migration of legacy series mappings

- [x] 3.1 During classification, detect legacy mappings (`source_instance_id` NULL) whose `source_event_id` is a recurring series in the listing; delete the legacy target event and remove the mapping before classifying its occurrences
- [x] 3.2 On failed legacy deletion, keep the mapping row for retry next cycle

## 4. Per-profile sync window

- [x] 4.1 Add `syncWindowDays` to `SyncProfile` (default 30) with persistence in `ProfileService` (read/write/copyWith)
- [x] 4.2 Add window dropdown (1 month / 3 months / 6 months / 1 year) to the profile form's Advanced section
- [x] 4.3 Add optional `end` parameter to `CalendarService.listEvents`; engine and background task pass `now + profile.syncWindowDays`

## 5. Tests

- [x] 5.1 Update `sync_engine_test.dart` recurring group: occurrence → standalone target (no recurrenceRule), 5 instances → 5 creates + 5 mappings
- [x] 5.2 Add tests: moved occurrence (old orphan deleted + new created), deleted occurrence exception, deleted series removes all instances, aged-out occurrence kept
- [x] 5.3 Add tests: legacy series mapping lazily replaced; legacy non-recurring mapping untouched; failed legacy deletion retries
- [x] 5.4 Update `mapping_database_test.dart` for the new column and UNIQUE constraint (two occurrences of same series allowed; same instance twice prevented)
- [x] 5.5 Update `profile_service_test.dart` for `sync_window_days` persistence and default
- [x] 5.6 Remove/replace tests asserting `canonical_time` and recurring target creation

## 6. Docs and verification

- [x] 6.1 Update `AGENTS.md` mapping table description to one-to-many with `source_instance_id`
- [x] 6.2 Run `flutter analyze` and `flutter test` clean
- [ ] 6.3 Manual check: sync a weekly series, move one occurrence in the source, re-sync, verify delete+create convergence in the target

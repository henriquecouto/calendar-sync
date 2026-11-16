# Tasks: Fix past instance deletion

## 1. Engine fix

- [x] 1.1 In `lib/sync/sync_engine.dart` `_processOrphanMappings`, change the occurrence branch (`source_instance_id != null`) to keep the target event when `targetEvent.endDate.isBefore(DateTime.now())` instead of the 7-day threshold; keep the threshold only on the non-recurring branch
- [x] 1.2 Keep the master fetch + delete logic for occurrence orphans whose target end time is still in the future
- [x] 1.3 Verify non-recurring orphan behavior (7-day grace → re-classify/delete) is unchanged

## 2. Tests

- [x] 2.1 Add regression test: synced occurrence that just passed (target end within last 7 days, master exists) is kept — target not deleted, mapping not removed
- [x] 2.2 Add test: deleted series keeps an already-passed occurrence target while deleting future ones
- [x] 2.3 Update `aged-out occurrence is kept` test if it relied on the >7-day wording; keep coverage for moved occurrence, deleted occurrence (future target), and deleted series (future targets)
- [x] 2.4 Run `flutter analyze` and `flutter test` — all green

## 3. Specs sync

- [x] 3.1 Sync the `event-sync` delta spec to `openspec/specs/event-sync/spec.md` (via `/opsx-sync` or the archive step) so the corrected orphan rule is codified in main specs

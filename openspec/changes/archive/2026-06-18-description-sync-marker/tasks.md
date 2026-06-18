## 1. Sync marker constant and creation logic

- [x] 1.1 Add `_syncMarker` constant to `sync_engine.dart`
- [x] 1.2 Modify `_execute`'s create flow to append marker to `description` parameter before calling `createEvent`
- [x] 1.3 Modify `_execute`'s update flow to append marker to `description` parameter before calling `createEvent` (replacement)

## 2. Title extraction for change detection

- [x] 2.1 In `_classifySingle`, when comparing `event.title` against `targetEvent.description` for `titleChanged`, use `targetEvent.description.startsWith(event.title)` instead of direct equality

## 3. Description-based loop detection

- [x] 3.1 In `_classifySingle`, add description marker check before the `sync_created_events` table check — skip if `event.description?.contains(_syncMarker) == true`
- [x] 3.2 Handle null description gracefully (fall through to `sync_created_events` check)

## 4. Tests

- [x] 4.1 Update existing test scenarios that assert description format to include the sync marker
- [x] 4.2 Add test: source event with marker in description is skipped (simulates Outlook re-ID)
- [x] 4.3 Add test: user event without marker is classified normally
- [x] 4.4 Add test: update detection correctly extracts original title from marked description
- [x] 4.5 Add test: null description does not crash (falls back to sync_created_events)

## 5. Cleanup

- [x] 5.1 Run `flutter analyze` and fix any warnings
- [x] 5.2 Run `flutter test` and confirm all tests pass

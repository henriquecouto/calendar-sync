## 1. Implementation

- [x] 1.1 Restore source-by-ID existence check in `_processOrphanMappings` at `lib/sync/sync_engine.dart:143`: after the 7-day threshold, call `_calendarService.getEvent(sourceEventId)`. If found, add to `sourceEvents` for re-classification. If null, add to `toDelete`.

## 2. Fix existing tests

- [x] 2.1 Fix test "recent event with source exists -> re-classified, not deleted" at `test/sync_engine_test.dart:92`: mock `getEvent('src-1')` to return an Event, assert `toDelete` is empty, verify `getEvent('src-1')` was called.
- [x] 2.2 Strengthen test "recent event with source gone -> deleted" at `test/sync_engine_test.dart:121`: explicitly mock `getEvent('src-1')` → null, verify the call happened.
- [x] 2.3 Strengthen "delete path" test at `test/sync_engine_test.dart:536`: add `verify(() => calendarService.getEvent('src-1')).called(1)`.

## 3. Add regression-prevention tests

- [x] 3.1 Add test: source found → re-classified through full pipeline. Mock `getEvent('src-1')` returns event, `getEvent('tgt-1')` returns matching target. Assert `toUpdate` empty and `toSkip` contains the event (source re-entered classify pipeline without deletion).
- [x] 3.2 Add test: source found with changed fields → classified as toUpdate (not just added to sourceEvents and forgotten).

## 4. Verification

- [x] 4.1 Run `flutter analyze` to verify no static analysis issues
- [x] 4.2 Run `flutter test` to confirm all tests pass
- [x] 4.3 Build debug APK with `flutter build apk --debug` to confirm compilation

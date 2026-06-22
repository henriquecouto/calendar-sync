## 1. Profile Config UI

- [x] 1.1 Remove `_eventNameError` state and the non-empty validation from `_save()` in `lib/screens/profile_config_screen.dart`
- [x] 1.2 Add helper text below the Sync Event Name field: "Leave empty to keep original event titles." using the same style as the Fallback Interval helper (`fontSize: 12, color: colorScheme.outline`)
- [x] 1.3 Remove `errorText` from the Sync Event Name `TextField` decoration (no longer needed)

## 2. Sync Engine

- [x] 2.1 In `_classifySingle()` (`lib/sync/sync_engine.dart`), change `projectedTitle` to use `syncEventName.isEmpty ? event.title : syncEventName`
- [x] 2.2 In `_execute()`, ensure the title passed to `createEvent()` comes from the entry's `projectedTitle` (added `projectedTitle` to `ToUpdateEntry`, fixed both create and update paths)

## 3. Dashboard & Sync Guards

- [x] 3.1 In `lib/screens/dashboard_screen.dart` `_syncProfile()`, remove the `syncName.isEmpty` guard — empty event names are now valid
- [x] 3.2 In `lib/background/sync_task.dart`, remove the `syncName.isEmpty` guard — empty event names are now valid
- [x] 3.3 Pass `profile.eventName` (which may be empty) to `engine.runSync()` in both dashboard and background paths (already the case, verified)

## 4. Profile Card Display

- [x] 4.1 In `lib/widgets/profile_card.dart`, when `profile.eventName` is empty, display "Original titles" instead of an empty string

## 5. Tests

- [x] 5.1 In `test/sync_engine_test.dart`, add a test that verifies `projectedTitle` is the source event's original title when `syncEventName` is empty
- [x] 5.2 In `test/sync_engine_test.dart`, add a regression test that verifies `projectedTitle` is the `syncEventName` when it is non-empty (existing behavior)

## 6. Quality Gates

- [x] 6.1 Run `flutter analyze` and fix all warnings and errors
- [x] 6.2 Run `flutter test` and confirm all existing tests pass and new tests pass
- [x] 6.3 Run `flutter build apk --debug` and confirm no build errors

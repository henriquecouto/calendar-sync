## 1. CalendarService Update

- [x] 1.1 Add optional `description` parameter to `CalendarService.createEvent()`
- [x] 1.2 Pass `description` to the `Event` constructor

## 2. SyncEngine Update

- [x] 2.1 Pass `event.title` as `description:` argument in `SyncEngine.runSync()` creation pass

## 3. Quality Gates

- [x] 3.1 Run `flutter analyze` and fix all warnings and errors
- [x] 3.2 Run `flutter test` and confirm existing tests pass
- [x] 3.3 Run `flutter build apk --debug` and confirm no build errors

## 1. Native Worker

- [x] 1.1 Create `ObserverRegistrationWorker.kt` extending `Worker` that calls `CalendarContentObserver.register()`
- [x] 1.2 Schedule the observer-registration periodic task in `MainActivity` with the same interval as the sync task

## 2. Quality Gates

- [x] 2.1 Run `flutter analyze` and fix all warnings and errors
- [x] 2.2 Run `flutter test` and confirm existing tests pass
- [x] 2.3 Run `flutter build apk --debug` and confirm no build errors

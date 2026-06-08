## 1. Setup

- [x] 1.1 Add `flutter_local_notifications` dependency to `pubspec.yaml`
- [x] 1.2 Run `flutter pub get` and verify no dependency resolution errors

## 2. Core Implementation

- [x] 2.1 Initialize `FlutterLocalNotificationsPlugin` and create notification channel in `callbackDispatcher()`
- [x] 2.2 After sync, show notification only when `result.synced.length > 0 || result.deleted.length > 0`
- [x] 2.3 Build notification body: "Synced: N, Deleted: M, Skipped: K" + errors suffix if any

## 3. Quality Gates

- [x] 3.1 Run `flutter analyze` and fix all warnings and errors
- [x] 3.2 Run `flutter test` and confirm existing tests pass
- [x] 3.3 Run `flutter build apk --debug` and confirm no build errors

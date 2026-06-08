## 1. Manifest

- [x] 1.1 Add `POST_NOTIFICATIONS` permission to `AndroidManifest.xml`

## 2. Permission Service

- [x] 2.1 Add `areNotificationPermissionsGranted` getter to `PermissionService`
- [x] 2.2 Add `requestNotificationPermission()` method

## 3. Permission Gate

- [x] 3.1 Update `PermissionGate` to request notification permission after calendar permissions

## 4. Quality Gates

- [x] 4.1 Run `flutter analyze` and fix all warnings and errors
- [x] 4.2 Run `flutter test` and confirm existing tests pass
- [x] 4.3 Run `flutter build apk --debug` and confirm no build errors

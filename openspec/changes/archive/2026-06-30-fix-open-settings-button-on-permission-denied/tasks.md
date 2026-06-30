## 1. Fix the recursive method

- [x] 1.1 Rename `PermissionService.openAppSettings()` to `openSystemSettings()` in `lib/permissions/permission_service.dart` — the new name avoids colliding with the top-level `openAppSettings()` from `permission_handler`, so the internal call now correctly delegates to the package function
- [x] 1.2 Update the call site in `lib/permissions/permission_gate.dart:74` from `_service.openAppSettings()` to `_service.openSystemSettings()`

## 2. Verification

- [x] 2.1 Run `flutter analyze` to confirm no static analysis issues
- [x] 2.2 Build debug APK with `flutter build apk --debug` to confirm compilation succeeds

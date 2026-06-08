## Why

Background sync notifications are not appearing. The `POST_NOTIFICATIONS` permission is required on Android 13+ for any app to show notifications. Without it, `flutter_local_notifications.show()` silently does nothing.

## What Changes

- Add `POST_NOTIFICATIONS` permission to `AndroidManifest.xml`
- Request notification permission in the app UI via `permission_handler`
- The PermissionGate now also checks notification permission

## Capabilities

### Modified Capabilities

- `permission-handling`: The permission gate now also requests `POST_NOTIFICATIONS` permission on Android 13+.

## Impact

- Modified: `android/app/src/main/AndroidManifest.xml`, `lib/permissions/permission_service.dart`, `lib/permissions/permission_gate.dart`

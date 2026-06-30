## Why

When calendar permissions are permanently denied, the app shows an "Open Settings" button so users can manually enable permissions in the system Settings app. Tapping this button does nothing because `PermissionService.openAppSettings()` calls itself recursively instead of calling the top-level `openAppSettings()` function from `permission_handler`. This leaves users stuck with no way to grant permissions after they've been permanently denied.

## What Changes

- Fix `PermissionService.openAppSettings()` to call the `permission_handler` top-level function instead of recursing into itself

## Capabilities

### New Capabilities

None — this is a bug fix, not a new capability.

### Modified Capabilities

None — the existing `permission-handling` spec already requires opening system settings via `openAppSettings()`. The requirements are unchanged; only the implementation is broken.

## Impact

- `lib/permissions/permission_service.dart` — fix the recursive `openAppSettings()` method call

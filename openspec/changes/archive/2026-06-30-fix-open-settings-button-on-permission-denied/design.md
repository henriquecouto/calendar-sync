## Context

`PermissionService.openAppSettings()` (lib/permissions/permission_service.dart:29) is intended to open the Android system Settings screen so users can manually grant calendar permissions after they've been permanently denied. However, the method calls itself recursively because Dart resolves the bare `openAppSettings()` call to the instance method rather than the top-level function from `permission_handler`. The "Open Settings" button in `permission_gate.dart` appears to do nothing because the call stack overflows silently.

## Goals / Non-Goals

**Goals:**
- Fix `PermissionService.openAppSettings()` so tapping the "Open Settings" button correctly opens the system Settings app

**Non-Goals:**
- Changing the permission flow or UI behavior
- Adding new entry points for settings navigation
- Re-architecting the permission service

## Decisions

**Decision: Rename the method to avoid the name collision**

Rename `PermissionService.openAppSettings()` to `PermissionService.openSystemSettings()`. Inside the method, call the top-level `openAppSettings()` from `permission_handler` (no collision now). Update the single call site in `permission_gate.dart` from `_service.openAppSettings()` to `_service.openSystemSettings()`.

**Alternatives considered:**

1. *Import alias* (`import '...' as permission_handler;`): Would require prefixing all `Permission.*` usages with `permission_handler.Permission.*`, touching more lines for no benefit.
2. *Hide the top-level symbol*: Doesn't help — the member still shadows the top-level. Would still need a rename or alias.
3. *Rename the method*: Cleanest fix. Only two lines change (definition + call site). No import changes needed. The new name `openSystemSettings` is more descriptive and avoids any future collision risk.

## Risks / Trade-offs

- [Very low] The rename slightly changes the public API of `PermissionService`, but it's only used internally in `permission_gate.dart`. No external consumers.

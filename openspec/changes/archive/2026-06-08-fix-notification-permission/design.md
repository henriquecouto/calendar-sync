## Context

`flutter_local_notifications.show()` silently fails on Android 13+ when `POST_NOTIFICATIONS` permission is denied by the user. The permission must be declared in the manifest and requested at runtime.

## Goals / Non-Goals

**Goals:**
- Declare `POST_NOTIFICATIONS` in AndroidManifest.xml
- Request permission in app UI before sync can run
- PermissionGate blocks until notification permission is granted

**Non-Goals:**
- Notification permission for iOS
- Foreground service permission

## Decisions

### Add to existing PermissionService + PermissionGate

Add `notification` permission check to the existing `PermissionService.areCalendarPermissionsGranted` logic. The PermissionGate now checks both calendar AND notification permissions.

### Runtime request flow

1. App launches → PermissionGate shown
2. User grants calendar permissions → request notification permission
3. User grants notification permission → app proceeds
4. Either denied → PermissionGate shows explanation

## Risks / Trade-offs

- [Risk] User may deny notification permission but want sync to work → Mitigation: keep notification permission separate from calendar permission check in callbackDispatcher. Sync runs regardless, just no notification shown.

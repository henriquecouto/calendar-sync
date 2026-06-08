## Context

The `callbackDispatcher()` in `lib/background/sync_task.dart` runs the sync engine silently. It catches all errors and returns without any user-visible output. The `SyncEngine.runSync()` returns a `SyncResult` with counts (synced, skipped, deleted, errors).

## Goals / Non-Goals

**Goals:**
- Show a local Android notification when background sync produces changes
- Notification summarizes: "Synced: N, Deleted: M, Skipped: K" (errors if any)
- Zero-activity syncs (counts all zero) produce no notification
- Silent skips (unconfigured, permissions denied) produce no notification

**Non-Goals:**
- Notification on manual "Sync Now" (the UI already shows results)
- Notification actions (tap to open app, dismiss, etc.)
- iOS or web notifications

## Decisions

### Use `flutter_local_notifications` package

The standard Flutter package for local notifications. Works in background isolates on Android. Requires:
- Notification channel creation (done once on app start or in callback)
- Android notification permission (POST_NOTIFICATIONS, Android 13+)

### Notification only for background sync paths

The `callbackDispatcher` already serves both the ContentObserver-reactive and periodic-fallback paths. Adding notification there covers both automatically. Manual sync via the UI button shows results inline — no notification needed.

### Notification content

```
Title: Calendar Sync
Body: Synced: N, Deleted: M, Skipped: K
```
If errors > 0: append `+ E errors`

### Channel setup

Channel ID: `calendar_sync`  
Channel name: `Calendar Sync`  
Importance: `default` (shows in status bar, no sound)

Channel creation happens once in the `callbackDispatcher` before showing the notification. `flutter_local_notifications` handles idempotency.

### Idempotent initialization

On every callback execution:
1. Initialize `FlutterLocalNotificationsPlugin` (lightweight after first init)
2. Create notification channel (no-op if already exists)
3. Run sync
4. If result has changes (synced + deleted > 0), show notification
5. Return

## Risks / Trade-offs

- [Risk] Notification permission not granted on Android 13+ → Mitigation: The plugin handles this gracefully; notification simply won't appear. Users can grant manually.
- [Risk] `flutter_local_notifications` may not work in background isolate on some Android versions → Mitigation: The plugin is tested for workmanager callback scenarios. Fallback: caught exception, no crash.

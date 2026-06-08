## Why

Background sync runs silently — the user has no way to know if sync happened or what changed. A notification after sync completes gives visibility into sync activity (what was created, deleted, or skipped).

## What Changes

- Show an Android notification after each background sync cycle summarizing the results
- Notification shows only when there was actual activity (N synced, M deleted, K skipped, E errors)
- Silent syncs (no changes, permissions denied, unconfigured) produce no notification
- Uses `flutter_local_notifications` for Android notification channel

## Capabilities

### Modified Capabilities

- `background-sync`: The background task now SHALL display a notification after sync completes when changes were detected.

## Impact

- New dependency: `flutter_local_notifications`
- Modified file: `lib/background/sync_task.dart` (post-sync notification)
- `android/app/src/main/AndroidManifest.xml` may need notification permission entries

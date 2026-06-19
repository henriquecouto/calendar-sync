## Why

Target events on Outlook calendars synchronized via DAVdroid are not properly deleted. When a source event is removed, the sync engine deletes the target event using `device_calendar_plus`'s hard-delete API, which physically removes the row from the Android Calendar Provider. DAVdroid does not see a `DELETED=1` flag and restores the event from the server as "(No title)", creating phantom events that persist indefinitely.

## What Changes

- **BREAKING**: `deleteEvent` in `CalendarService` now returns `CalendarDeleteResult` (was `bool`)
- New native `SoftDeletePlugin` (FlutterPlugin) that performs soft-delete by setting `DELETED=1` + `DIRTY=1` on the Android Calendar Provider with sync-adapter context URI, then requests an immediate sync so DAVdroid propagates the deletion to the Outlook server
- Gradle build task that automatically injects the `SoftDeletePlugin` into `GeneratedPluginRegistrant.java`, ensuring it works in both foreground and background Flutter engines
- `CalendarService.deleteEvent` calls the soft-delete MethodChannel first; falls back to the plugin's hard-delete only if the channel fails
- Orphan detection in `_processOrphanMappings` no longer calls `getEvent(sourceEventId)` as a safety check, since Android soft-deletes (marked `DELETED=1`) are filtered by `listEvents` but still findable by `getEvent`
- Hard-delete fallback includes a 5-second post-deletion verification: if the event reappeared (provider restored it), the mapping is preserved for a retry on the next sync cycle

## Capabilities

### Modified Capabilities

- `event-sync`: Delete flow uses soft-delete (native `DELETED=1` flag) instead of hard-delete for target events, so sync adapters can propagate deletions to remote servers. Orphan detection simplified to trust `listEvents` over `getEvent`.

## Impact

- `lib/calendar/calendar_service.dart` — new `CalendarDeleteResult` class, MethodChannel soft-delete call
- `lib/sync/sync_engine.dart` — removed `getEvent(sourceEventId)` check in `_processOrphanMappings`, updated delete loop with hard-delete verification
- `android/.../SoftDeletePlugin.kt` (new) — native FlutterPlugin implementing soft-delete with sync-adapter context
- `android/app/build.gradle.kts` — Gradle task to inject SoftDeletePlugin into GeneratedPluginRegistrant
- `android/app/src/main/java/.../GeneratedPluginRegistrant.java` — auto-injected plugin registration

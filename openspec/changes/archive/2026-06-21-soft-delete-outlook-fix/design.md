## Context

The app syncs events between local Android calendars using the `device_calendar_plus` plugin. When a source event is deleted, the sync engine detects the orphaned mapping and calls `deleteEvent()` on the target calendar. The plugin performs a hard-delete using `ContentResolver.delete()` with sync-adapter context, which physically removes the event row from the Android Calendar Provider.

**Problem**: On devices with DAVdroid syncing to Outlook/Exchange, hard-deleting an event bypasses the sync adapter's detection mechanism. Android Calendar Provider's standard approach for deletion propagation is to set `DELETED=1` on the event row. Sync adapters read this flag and push the deletion to the server. When the row is physically removed, DAVdroid sees a missing event locally, assumes it was accidentally lost, and restores it from the server as a "(No title)" event.

**Constraints**:
- Must work in both foreground (manual sync) and background (Workmanager periodic sync) contexts
- Cannot modify the `device_calendar_plus` plugin (pub cache is ephemeral)
- Must use sync-adapter context URI (`CALLER_IS_SYNCADAPTER=true`) to write to `DIRTY` field
- Must handle the case where platform channel is unavailable (background engine without plugin registration)

## Goals / Non-Goals

**Goals:**
- Delete target Outlook events so DAVdroid propagates the deletion to the server
- Work identically in foreground and background sync
- Keep all implementation within the app's own codebase (no pub cache patches)

**Non-Goals:**
- Change the plugin's behavior for non-Outlook calendars
- Add UI for deletion status
- Handle recurring event instance deletions differently (existing exception-based approach is fine)

## Decisions

### 1. Native FlutterPlugin with Gradle Injection for Background Support

**Chosen**: Create `SoftDeletePlugin` implementing `FlutterPlugin` + `MethodChannel.MethodCallHandler`, registered via a Gradle task that injects it into `GeneratedPluginRegistrant.java` after each build.

**Alternatives considered**:
- *MethodChannel in MainActivity only* → Does not work in background (Workmanager creates a separate FlutterEngine without Activity).
- *Modify the pub cache plugin* → Ephemeral; overwritten on `flutter pub get`.
- *Use ContentResolver directly without sync-adapter context* → Calendar Provider rejects writes to DIRTY field: "Only sync adapters may write to dirty".

**How it works**: The Gradle task `injectSoftDeletePlugin` runs after Kotlin compilation. It inserts the plugin registration before the closing brace of `GeneratedPluginRegistrant.registerWith()`. This ensures the plugin is registered for every FlutterEngine, including the one Workmanager creates for background tasks.

### 2. Soft-Delete via DELETED=1 + DIRTY=1 with Sync-Adapter URI

**Chosen**: Update the event row setting both `CalendarContract.Events.DELETED = 1` and `CalendarContract.Events.DIRTY = 1`, using a URI built with `CALLER_IS_SYNCADAPTER=true` + account name/type query parameters.

**Rationale**: DELETED=1 marks the event for deletion (Etar does this). DIRTY=1 ensures the sync adapter picks it up immediately. The sync-adapter context URI is required by Android Calendar Provider to allow writing to DIRTY. After the update, `ContentResolver.requestSync()` is called for all accounts to force immediate sync.

### 3. CalendarDeleteResult Return Type

**Chosen**: Change `deleteEvent` signature from `Future<bool>` to `Future<CalendarDeleteResult>` with `success` and `usedSoftDelete` flags.

**Rationale**: The sync engine needs to know whether soft-delete was used to decide if post-deletion verification is needed. Soft-delete keeps the row (with DELETED=1), so `getEvent` would still find it. Hard-delete removes the row, so verification is appropriate.

### 4. Orphan Detection Without getEvent(sourceEventId) Safety Check

**Chosen**: Remove the `getEvent(sourceEventId)` call that was re-finding soft-deleted source events and blocking deletion.

**Rationale**: Android Calendar Provider soft-deletes by setting DELETED=1. `listEvents` filters these out (correctly showing the source as gone), but `getEvent` still returns them. The safety check was meant to prevent false positives but caused false negatives with soft-deleted events.

## Risks / Trade-offs

- **GeneratedPluginRegistrant.java is regenerated on flutter pub get** → Our Gradle task re-injects the plugin after every Kotlin compilation, so builds always include it. `flutter pub get` alone would remove it, but the next `flutter build` restores it.
- **Soft-delete only works for non-recurring events** → The `deleteEventMaster` path was modified. Instance deletions (`deleteEventInstance`) and recurring truncation (`deleteRecurringThisAndFollowing`) still use the plugin's original hard-delete approach. For now, only non-recurring events are affected.
- **Fallback to hard delete may still cause Outlook restoration** → The 5-second post-delete verification catches this case and preserves the mapping, so the event will be re-deleted on the next sync cycle.

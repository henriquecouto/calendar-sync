## Why

The current `CalendarService.deleteEvent()` uses a brittle two-tier strategy: manually set `DELETED=1` via platform channel (soft delete), then fall back to `device_calendar_plus` hard delete. Both paths are wrong. The manual soft delete over-engineers what the Calendar Provider already does automatically. The `device_calendar_plus` fallback uses `CALLER_IS_SYNCADAPTER=true` to force physical deletion — which silently breaks for synced calendars because their sync adapter recreates the event. The Android Calendar Provider already handles soft-vs-hard delete automatically: calling `ContentResolver.delete()` on a plain `Events.CONTENT_URI` makes the Provider decide based on calendar type (synced → DELETED=1, local → row removed). Following Etar's approach, we replace the entire delete stack with a single standard `ContentResolver.delete()` call.

## What Changes

- **BREAKING**: Remove the manual `DELETED=1` + `requestSync` approach in `SoftDeletePlugin.kt`
- **BREAKING**: Remove the `device_calendar_plus` fallback in `CalendarService.deleteEvent()`
- Replace `SoftDeletePlugin`'s delete logic with a single `ContentResolver.delete(Events.CONTENT_URI, ...)` call — the Calendar Provider handles soft vs hard automatically
- Remove `buildSyncAdapterUri`, `readCalendarAccount`, manual `requestSync` from the Kotlin plugin (all dead code)
- `CalendarService.deleteEvent()` no longer needs `calendarId` — the Provider determines calendar type from the event ID internally
- `CalendarDeleteResult` simplifies to `success` only (no `usedSoftDelete` flag)
- Sync engine removes the 5-second re-check after hard delete — no longer needed since the Provider always uses the correct strategy

## Capabilities

### New Capabilities
- `standard-delete`: Standard Android `ContentResolver.delete()` on plain `Events.CONTENT_URI`, leveraging the Calendar Provider's built-in soft vs hard delete behavior based on calendar sync status.

### Modified Capabilities
- `calendar-access`: The delete requirement changes from "soft-delete-via-platform-channel-with-fallback" to "standard `ContentResolver.delete()` delegating to the Calendar Provider".

## Impact

- `android/.../SoftDeletePlugin.kt`: ~100 lines removed, replaced with ~10 lines
- `lib/calendar/calendar_service.dart`: `deleteEvent` simplified, `device_calendar_plus` fallback removed
- `lib/sync/sync_engine.dart`: Removes hard-delete re-check, passes no `calendarId`
- `CalendarDeleteResult`: only `success` bool remains

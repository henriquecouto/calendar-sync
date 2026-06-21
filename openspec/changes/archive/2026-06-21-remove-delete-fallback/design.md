## Context

The current delete flow does manually what the Android Calendar Provider already does automatically:

```
Current:
  SoftDeletePlugin: query account → build sync-adapter URI → update(DELETED=1,DIRTY=1)
                   → requestSync(all accounts)
  Fallback: device_calendar_plus.deleteEvent()
           → buildDeleteUri with CALLER_IS_SYNCADAPTER → ContentResolver.delete()
           → forces physical deletion even for synced calendars → sync adapter recreates

Goal (Etar approach):
  Platform channel: ContentResolver.delete(Events.CONTENT_URI, "_id=?", [eventId])
  Calendar Provider internally:
    ├─ Synced calendar → auto-sets DELETED=1, DIRTY=1, triggers sync
    └─ Local calendar → physically removes the row
```

The Calendar Provider checks each event's parent calendar for an associated sync adapter. When a sync adapter exists, `delete()` marks the row as deleted instead of removing it — the sync adapter then detects the `DIRTY` flag and propagates the deletion to the server. When no sync adapter exists, the row is physically removed.

`device_calendar_plus` explicitly opts OUT of this behavior by using `CALLER_IS_SYNCADAPTER=true` to force physical deletion always. That's their design choice for a general-purpose calendar library. For our app, the standard Provider behavior is exactly what we want.

## Goals / Non-Goals

**Goals:**
- Replace the entire manual delete stack with a single `ContentResolver.delete()` call on plain `Events.CONTENT_URI`
- Remove all sync-adapter URI construction, account queries, manual DELETED=1/DIRTY=1, and requestSync logic from the plugin
- Remove the `device_calendar_plus` delete fallback
- Simplify `CalendarDeleteResult` to `success` only
- Remove the 5-second re-check from sync engine
- `CalendarService.deleteEvent()` takes only `eventId` (no `calendarId`)

**Non-Goals:**
- Implementing single-occurrence deletion for recurring events (`STATUS_CANCELED` exception events)
- Changing how events are listed, created, or retrieved
- Adding calendar type detection anywhere

## Decisions

### Decision 1: Plain `ContentResolver.delete()` on `Events.CONTENT_URI`

The platform channel calls exactly:

```kotlin
ctx.contentResolver.delete(
    CalendarContract.Events.CONTENT_URI,
    "${CalendarContract.Events._ID} = ?",
    arrayOf(eventId)
)
```

No `CALLER_IS_SYNCADAPTER`, no account query params, no manual `ContentValues`. The Calendar Provider inspects the event's calendar and applies the correct strategy.

**Alternative considered**: Keep the manual `ContentResolver.update(DELETED=1)` on a sync-adapter URI. Rejected because it reimplements Provider behavior in a more complex, error-prone way (scoping requestSync to affected account only, building correct URI, etc.).

**Alternative considered**: Use `device_calendar_plus.deleteEvent()` for local calendars. Rejected because it uses `CALLER_IS_SYNCADAPTER=true` which forces physical deletion even for synced calendars — the same problem we're fixing.

### Decision 2: No calendarId parameter

The Provider looks up the event's calendar internally from the event ID. No need to pass `calendarId` from Dart. This simplifies the API and eliminates any risk of passing the wrong calendar ID.

### Decision 3: Simplify CalendarDeleteResult

Only `success: bool`. The `usedSoftDelete` flag served no purpose beyond the 5-second re-check, which is now removed.

### Decision 4: eventId as String

The platform channel receives `eventId` as `String` (not `Long`). SQLite's type affinity allows TEXT comparison against the `_ID` INTEGER column. This supports non-numeric IDs from Outlook and other providers.

## Risks / Trade-offs

- **[Risk] `ContentResolver.delete()` on plain URI for a synced calendar may not trigger `requestSync` promptly on all Android versions** → The Provider sets `DIRTY=1` which the sync adapter framework picks up eventually (usually within seconds). If the sync adapter doesn't run immediately, the event lingers as DELETED=1 until the next automatic sync. This is acceptable — the standard Android behavior, same as Etar and Google Calendar.
- **[Trade-off] No manual `requestSync` means no guaranteed immediate sync propagation** → Acceptable. The current manual requestSync already iterates ALL accounts indiscriminately, which is arguably worse (unnecessary syncs). The Provider's automatic behavior is more targeted.
- **[Risk] Non-numeric event IDs from Outlook** → SQLite `_ID` column is INTEGER but SQLite allows TEXT comparison. The same approach is used by `device_calendar_plus` which also passes string IDs to `_ID` queries.

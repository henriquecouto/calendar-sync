## Why

Target (synced) events are being incorrectly deleted in two scenarios:
1. A source event naturally moves into the past — the fetch window excludes it, the engine falsely flags it as deleted.
2. A source event is edited to a past date — the target still holds the old future date, so a stale end-time check falsely confirms deletion.

The root cause is that the sync engine infers deletion from absence in a time-windowed fetch, without ever confirming whether the source event still exists.

## What Changes

- For any mapped source event absent from the fetch window, check the target event's end time against a 7-day threshold:
  - `target.end < now - 7d` → ignore (past event, deletion irrelevant).
  - `target.end >= now - 7d` → fetch the source event by ID to confirm existence. If it exists, re-classify (update target). If gone, delete target.
- Fix `CalendarService.getEvent()` to fetch by event ID directly (`RetrieveEventsParams.eventIds`) instead of scanning a time-windowed result.
- Add null-safety guards for target event start/end in the comparison logic.

## Capabilities

### New Capabilities

_None — this fix modifies existing behavior only._

### Modified Capabilities

- `event-sync`: The deletion classification logic must gate deletion on a 7-day recency threshold. Past events (target.end < now - 7d) are never deleted even if the source event is absent from the fetch window. Recent events (target.end >= now - 7d) trigger a source-by-ID existence check before deletion.
- `calendar-access`: `getEvent()` fetches by ID directly (no time window).

## Impact

- `lib/calendar/calendar_service.dart` — `getEvent()` uses direct ID fetch via `RetrieveEventsParams.eventIds`
- `lib/sync/sync_engine.dart` — deletion pass checks target.end against 7-day threshold, then confirms via source-by-ID; null-guards for target event times
- Existing mapping table schema is unchanged

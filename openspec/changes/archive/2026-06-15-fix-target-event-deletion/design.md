## Context

The sync engine calls `CalendarService.listEvents()` with `startDate: now`, which excludes past events. When a source event is absent from the fetch, the engine incorrectly infers it was deleted. The target.end gate failed because the target is a stale copy.

The correct approach uses a **recency threshold**: old past events are ignored entirely; recent past events trigger a source-by-ID existence check.

## Goals / Non-Goals

**Goals:**
- Skip deletion for old past events (target.end < now - 7d) without any source fetch
- Confirm source existence by ID for recent past events before deleting
- When source exists but was missed by fetch, re-classify for update
- Add null-safety checks for target event start/end in comparison logic

**Non-Goals:**
- Changing the mapping table schema
- Changing the calendar service fetch window
- Changing the create or update paths
- Handling recurring event expansion

## Decisions

### Decision 1: 7-day recency threshold + source-by-ID confirmation

The deletion confirmation has two tiers:

**Tier 1 — Skip old events cheaply:**
Fetch the target event by ID from the mapping. Check `target.end`:

```
target == null           → clean up orphan mapping
target.end < now - 7d    → skip (old past event, ignore)
target.end >= now - 7d   → proceed to Tier 2
```

This gate requires 1 API call (target fetch) per unmapped source. Old events stop here — no source fetch needed.

**Tier 2 — Precise confirmation for recent events:**
Fetch the source event by ID:

```
sourceEvent != null → event exists (edited/moved to past) → re-classify
sourceEvent == null → event truly deleted → delete target + remove mapping
```

If the source exists, add it back into the classification loop: compare with target, update if fields differ.

**Alternatives considered:**
- *Source-by-ID for every unmapped source*: N API calls per sync for every past mapped event. Rejected — old events trigger wasted fetches.
- *Widen fetch window with lookback*: Same problem for events beyond the lookback. Plus fetches more events in the batch call. Rejected.
- *Store timestamps in mapping table*: Schema migration burden. Rejected.

### Decision 2: Fetch window stays as `now → now+30d`

No lookback needed. The 7-day threshold on target.end handles recency without widening the batch fetch.

### Decision 3: Fix `getEvent` to fetch by ID directly

Uses `RetrieveEventsParams(eventIds: [eventId])` — works for events at any time, bypassing the fetch window.

### Decision 4: Add null-guards for target event start/end

Before comparing source and target event times, check that `targetEvent.start` and `targetEvent.end` are non-null. Skip if null.

## Risks / Trade-offs

- **Risk**: Each unmapped source triggers 1 target fetch (Tier 1). For recent events (\(\leq\) 7 days), adds 1 more source fetch (Tier 2, 2 total).
  - **Mitigation**: Target fetch by ID is cheap. Source fetch by ID only for recent events, which are few in practice.

- **Risk**: If target.end is exactly on the threshold boundary, behavior depends on millisecond timing.
  - **Mitigation**: `isBefore` comparison means the threshold is exclusive at the lower bound. 7 days is approximate — perfect precision is unnecessary.

- **Risk**: Null target event start/end silently skips update.
  - **Mitigation**: Edge case unlikely with `device_calendar`. Log entry emitted for debugging.

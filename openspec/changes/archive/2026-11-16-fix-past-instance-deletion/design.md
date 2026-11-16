# Design: Fix past instance deletion

## Context

`_processOrphanMappings` in `lib/sync/sync_engine.dart` resolves mappings whose `(event_id, instance_id)` did not appear in the source listing. Because `CalendarService.listEvents` starts at `now`, an occurrence of a recurring series disappears from the listing as soon as its time passes — exactly like a deleted occurrence. The current rule only distinguishes them by a 7-day grace on the **target** event's end time:

```dart
final threshold = DateTime.now().subtract(const Duration(days: 7));
if (targetEvent.endDate.isBefore(threshold)) {
  continue; // keep
}
// otherwise: fetch master; master exists → delete target + mapping
```

This keeps occurrences older than 7 days but deletes occurrences that passed within the last 7 days: the master fetch returns the series master (it exists), so the engine concludes the occurrence was "moved or deleted as an exception" and deletes the target event. Users see a synced event disappear from the target calendar right after it happens.

The design of change #64 (`2026-11-13-sync-recurring-as-instances`, decision D3) explicitly intended past occurrences to be kept ("an occurrence that simply aged out of the window has a target event in the past (or just happened), so it is kept, not deleted"), but the grace boundary was inverted.

## Goals / Non-Goals

**Goals:**

- A synced target event for an occurrence that has already passed is never deleted by the sync engine.
- Moved or deleted **future** occurrences still converge: old slot deleted, new slot created.
- Deleted series still removes its **future** occurrence targets.
- Non-recurring orphan semantics stay as they are today.

**Non-Goals:**

- No lookback in `listEvents`; the listing still starts at `now` (past occurrences are never backfilled).
- No provider query for past instances to distinguish "just passed" from "deleted after passing" — past is simply never touched.
- No change to the mapping schema or the 7-day threshold for non-recurring events.
- No behavior change for occurrences whose target event is still in the future.

## Decisions

### D1: Occurrence orphans with a past target are kept unconditionally

In `_processOrphanMappings`, the occurrence branch (`source_instance_id != null`) checks the **target** event's end time against `now` instead of `now − 7 days`:

```
target event missing          → remove mapping + created_events row  (unchanged)
target end is before now      → keep (past occurrences are never touched)
target end is in the future   → fetch master:
    master exists             → moved/deleted exception → delete target + mapping
    master gone               → series deleted → delete target + mapping
```

The 7-day threshold remains only on the non-recurring branch (`source_instance_id == null`), which keeps its current behavior (re-classify if the source still exists, delete if gone).

**Alternatives considered:**

- **Lookback listing (start `listEvents` at `now − 7d`)** — recently passed occurrences would still be listed and classified normally, which also propagates "deleted just-past occurrence" correctly. Rejected: violates the documented non-goal "past occurrences are never backfilled" (a new profile's first sync would materialize the last 7 days) and touches classification semantics beyond the bug.
- **Hybrid (delete past target when the master is gone)** — would remove just-passed occurrences when the whole series is deleted. Rejected: contradicts "past is never touched" and adds complexity for a case users are unlikely to distinguish from a keep.
- **Master check with instance-id introspection** — no provider API reliably reports whether a specific past instance still exists. Rejected as infeasible on `device_calendar_plus`.

### D2: Boundary uses the target's end time vs `now`

An occurrence whose target event has already ended (`endDate.isBefore(now)`) is "past". A target still in progress or in the future is resolved via the master. This preserves the moved-occurrence behavior: the old slot of a moved occurrence is in the future, so it is still deleted.

### D3: Non-recurring branch is untouched

Non-recurring orphans keep the 7-day grace: a non-recurring source event absent from the listing with a recent target is still re-classified (update/create) or deleted if the source is gone. This preserves the existing spec scenarios ("Recent past event with source still existing", "Recent past event with source truly deleted") and avoids scope creep.

## Risks / Trade-offs

- **[Deleting a just-passed occurrence no longer propagates]** If the user deletes an occurrence exception after it already happened, the past target event stays (stale). → Accepted trade-off: "past occurrences are never touched" is the design's own non-goal; a stale past event is far less visible than the current bug of deleting every past event.
- **[Moved occurrence from a past slot leaves a stale past target]** If the user moves an occurrence from yesterday to next week, the old past target is kept and the new one is created. → Accepted; same rationale. The moved slot converges only for future slots, which is where moves are normally made.
- **[Deleted series keeps its just-passed targets]** Deleting a whole series right after an occurrence passed leaves that one past target. → Accepted; future targets are still removed, and history is preserved.
- **[Regression risk on future-slot resolution]** The master-based delete for future targets is unchanged, but tests must pin it (moved occurrence, deleted occurrence, deleted series with future targets). → Covered by existing + new tests in `test/sync_engine_test.dart`.
- **[Boundary at `now`]** An occurrence ending exactly at sync time is resolved via master; if it was deleted at the same moment the target would be removed. → Negligible; time comparison uses `millisecondsSinceEpoch` so the window is effectively zero.

## Migration Plan

- No schema or data migration; only engine logic changes.
- Existing mappings whose target events were already deleted by the bug are not restored (their mappings were removed). Users re-create the source occurrence only if they want a target again — acceptable for a fix release.
- Rollback: reverting the change restores the previous behavior; no persisted state to reconcile.

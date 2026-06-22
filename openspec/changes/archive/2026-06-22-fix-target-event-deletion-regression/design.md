## Context

The sync engine's `_processOrphanMappings` method handles source-to-target mappings where the source event is absent from `listEvents(now, now+30d)`. The original `fix-target-event-deletion` change (Jun 15) implemented a two-tier deletion confirmation:

- **Tier 1 (cheap):** Fetch target event by ID. If null → clean orphan mapping. If `target.end < now - 7d` → skip (old event). If recent → proceed to Tier 2.
- **Tier 2 (precise):** Fetch source event by ID. If found → re-classify. If null → truly deleted, delete target.

The `soft-delete-outlook-fix` change (Jun 19) removed Tier 2 entirely at `sync_engine.dart:143`, replacing it with a blind `toDelete.add(mapping)`. The rationale was that `getEvent(sourceEventId)` — which queries `Events.CONTENT_URI` directly without filtering `DELETED=1` — was returning soft-deleted source events, causing false negatives (target not deleted when source was genuinely deleted).

However, this trade-off causes **false positives**: any source event that moved outside the fetch window (edited to past, far future) has its target deleted. This is irreversible data loss.

## Goals / Non-Goals

**Goals:**
- Restore the source-by-ID existence check (Tier 2) after the 7-day threshold
- When source exists, add it to `sourceEvents` for re-classification (update path)
- When source is truly gone (null), proceed with target deletion
- Accept one-sync-cycle delay for soft-deleted (DELETED=1) source events

**Non-Goals:**
- Changing the 7-day threshold logic (Tier 1 is correct)
- Changing the fetch window (`now → now+30d`)
- Changing the delete, create, or update execution paths
- Modifying `CalendarService.getEvent()` or `deleteEvent()`
- Implementing a native check for the `DELETED` column

## Decisions

### Decision 1: Restore Tier 2 source-by-ID check, accept soft-delete delay

**Chosen:** After Tier 1 confirms the target is recent (`end >= now - 7d`), call `_calendarService.getEvent(sourceEventId)`. If the source event is returned, add it to `sourceEvents` (re-classify). If null, delete target.

```
Target end < now-7d        → skip (unchanged)
Target end >= now-7d        → getEvent(sourceEventId)
  ├─ found → sourceEvents.add(sourceEvent)   ← RESTORED
  └─ null  → toDelete.add(mapping)            ← RESTORED
```

**Rationale:** A false negative (not deleting when source is soft-deleted) delays deletion by at most one sync cycle. A false positive (deleting when source still exists) causes irreversible data loss. The safer choice is the slower one.

**Alternatives considered:**
- *Keep current behavior (blind delete):* Rejected. Already causing issue #13.
- *Add native DELETED column check:* Rejected. Requires modifying the platform channel and writing native code for a narrow edge case. Over-engineering for a delay of one sync cycle.
- *Widen fetch window to include lookback:* Rejected. Doesn't solve the problem for events edited to past dates beyond the lookback.

### Decision 2: No DELETED-aware native check

**Chosen:** Do NOT add a platform channel method to check the `DELETED` column for source events.

**Rationale:** The `getEvent` method in `device_calendar_plus` queries `Events.CONTENT_URI` without `DELETED != 1` filter. Adding a native check would require a new MethodChannel method querying the Provider directly with the `DELETED` column. This adds complexity and maintenance burden for minimal benefit. The one-sync-cycle delay for soft-deleted Outlook events is acceptable.

### Decision 3: `sourceEvents` parameter is already plumbed

**Chosen:** Use the existing `sourceEvents: List<Event>` parameter of `_processOrphanMappings` to add found events back.

**Rationale:** The parameter was part of the original design. `_classify` calls `_processOrphanMappings` before iterating over `sourceEvents`, so any events added to the list will be picked up by the subsequent for-loop. The signature already supports this flow — it just needs the implementation restored.

## Test Strategy

The existing test group `Deletion pass 7-day threshold + source-by-ID` at `test/sync_engine_test.dart:62` contains three tests that must be updated:

### Test to fix: "recent event with source exists → re-classified, not deleted" (line 92)

This test has a contradictory name vs. assertion. The name describes the correct behavior (re-classify, not delete) but the assertion `expect(plan.toDelete.length, 1)` was updated to match the regression. Fix:

- Mock `calendarService.getEvent('src-1')` → return an Event
- Assert `plan.toDelete` is empty
- Verify `calendarService.getEvent('src-1')` was called

### Test to strengthen: "recent event with source gone → deleted" (line 121)

This test passes by accident — mocktail returns null for unmocked methods, which coincidentally means "source gone." Strengthen:

- Explicitly mock `calendarService.getEvent('src-1')` → return null
- Verify `calendarService.getEvent('src-1')` was called

### Test to add: re-classification pipeline verified

When a source event is found and added to `sourceEvents`, it enters `_classifySingle`. Verify:

- Mock a full re-classification: getEvent('src-1') returns event, getEvent('tgt-1') returns matching target
- Assert `toUpdate` is empty and `toSkip` contains the event (no fields changed)
- Verify `isEventSynced` and `isEventCreatedBySync` were called

### Test to strengthen: execute path at line 536

The `runSync` test already covers delete execution, but doesn't verify the classification step:

- Add `verify(() => calendarService.getEvent('src-1')).called(1)`

Together these tests prevent the source-by-ID check from being silently removed again.

## Risks / Trade-offs

- **[Risk] Soft-deleted source events (DELETED=1 on Outlook/DAVdroid) will not trigger target deletion until the source row is cleaned up.** → The source event will be found by `getEvent`, added to `sourceEvents`, and re-classified. Since it already has a mapping, it goes to the update path. The update path fetches the target, compares fields, and may update or skip — but the target is never deleted. On the next sync cycle, the same thing happens unless the source row was finally cleaned up. → **Mitigation:** This is a delay, not a failure. The target event remains but will eventually be deleted when the source row is removed. In the worst case, the user sees a stale target event for one additional sync period.

- **[Risk] Re-classifying a source event that genuinely moved outside the window triggers an unnecessary update.** → The re-classification may detect time/title changes and recreate the target event. If nothing changed, the event is skipped. This is acceptable behavior.

- **[Risk] `getEvent(sourceEventId)` is O(n) per orphan mapping.** → Only events with recent targets (end >= now-7d) trigger the call, which is a small subset. Acceptable.

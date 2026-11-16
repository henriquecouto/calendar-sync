# Proposal: Fix past instance deletion

## Why

Since the recurring-events-as-instances change (#64), a synced occurrence of a recurring source event is deleted from the target calendar as soon as its time passes: the occurrence disappears from the listing (which starts at `now`), is classified as an orphan, and — because the series master still exists — the engine treats it as a moved/deleted exception and deletes the target event. Past occurrences that just happened (within 7 days) vanish from the target, while older ones (>7 days) are kept; the boundary is inverted and contradicts the design's own intent that past occurrences are never touched.

## What Changes

- In orphan resolution for mapped recurring occurrences (`source_instance_id` non-null), the engine SHALL keep (not delete) the target event when the target event's end time is already in the past. The current 7-day grace is replaced by this simpler rule: past target events are never deleted; only occurrences whose target event is still in the future are resolved via the series master (moved/deleted exception → delete; series deleted → delete).
- Non-recurring orphan resolution (`source_instance_id` null) keeps its current behavior: re-classify if the source still exists, delete if it is gone, still gated by the 7-day grace on the target end time.
- The `event-sync` spec is updated to codify the corrected rule and the affected scenarios.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `event-sync`: the "Run full sync cycle" requirement changes — for orphaned occurrence mappings whose target event has already ended, the system keeps the target event instead of deleting it; the 7-day threshold no longer applies to occurrence orphans.

## Impact

- `lib/sync/sync_engine.dart` — `_processOrphanMappings`: occurrence-orphan branch checks `targetEvent.endDate.isBefore(now)` and keeps past target events.
- `openspec/specs/event-sync/spec.md` — updated orphan resolution requirement and scenarios.
- `test/sync_engine_test.dart` — new regression tests: just-passed occurrence is kept; moved/deleted future occurrence still deleted; deleted series with just-passed occurrence keeps the past target.

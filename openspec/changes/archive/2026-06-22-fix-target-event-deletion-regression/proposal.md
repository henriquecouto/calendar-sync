## Why

The sync engine is deleting target events when a source event simply moves outside the `now → now+30d` fetch window (e.g., edited to a past date, moved far into the future). This regression was introduced by the `soft-delete-outlook-fix` change (commit `536da4f`), which removed the source-by-ID existence confirmation that the original `fix-target-event-deletion` change (commit `1b314e5`) had added. The removal was intentional — to handle DELETED=1 soft-deleted source events on Outlook/DAVdroid calendars where `getEvent()` still returns the row — but it re-introduced the original data-loss bug as a trade-off.

Now issue #13 ("target event is being deleted when the source event is over") is happening again.

## What Changes

- Restore the source-by-ID existence check in `_processOrphanMappings` after the 7-day threshold gate (Tier 2 logic from the original fix).
- When a source event is absent from `listEvents` but found via `getEvent(eventId)`, re-classify it (add to `sourceEvents`) instead of deleting the target.
- When a source event is truly gone (`getEvent` returns null), proceed with target deletion.
- Remove the soft-delete workaround that blindly deletes without source confirmation.
- Accept that soft-deleted source events (DELETED=1) will delay target deletion by one sync cycle — a safe trade-off vs. irreversible data loss.

## Capabilities

### New Capabilities

_None — this change restores previously-existing behavior._

### Modified Capabilities

- `event-sync`: The "Recent past event with source deleted" scenario currently specifies deletion "without re-fetching the source event by ID." This must change to require source-by-ID confirmation before deletion (matching the original fix-target-event-deletion behavior).

## Impact

- `lib/sync/sync_engine.dart` — `_processOrphanMappings`: add `_calendarService.getEvent(sourceEventId)` call after 7-day threshold, add found events to `sourceEvents` list for re-classification.
- `lib/calendar/calendar_service.dart` — no changes required; `getEvent(eventId)` already works for direct ID lookup.
- Existing mapping table, delete path, create path, update path: no changes.

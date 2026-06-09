## Context

The current `SyncEngine.runSync()` handles two operations: creation (new source events → target events) and deletion (missing source events → remove target events). Already-synced events (those with a mapping) are skipped entirely. If a user edits a synced event's time or title in the source calendar, the target calendar retains stale data.

## Goals / Non-Goals

**Goals:**
- Detect changes to already-synced source events (start time, end time, title)
- Update the corresponding target event to reflect the changes
- Track updated events separately in the sync result

**Non-Goals:**
- Partial updates (e.g., only time changed, keep description) — full replacement is simpler and sufficient
- Change detection via diff/hash — do a simple field-by-field comparison on each sync cycle
- Updating recurrence rules or other complex event fields

## Decisions

### Decision 1: Compare source and target events on each sync cycle

**Chosen:** For each already-synced source event, fetch the target event and compare its `start`, `end`, and `description` fields against what the source event should produce. If any differ, call `createOrUpdateEvent` (the `device_calendar` plugin uses the same API for both create and update via `eventId`).

**Rationale:**
- Simple field comparison, no state tracking between cycles
- Reuses existing `CalendarService.createEvent()` (which calls `createOrUpdateEvent` with eventId from mapping)
- Consistent with the idempotent design of the sync engine

### Decision 2: Add `updated` field to `SyncResult`

**Chosen:** `SyncResult` gains an `updated: UnmodifiableListView<String>` field listing the event IDs that were updated. Status messages and history entries include the update count.

**Rationale:**
- Users can see that changes were propagated, not just created/deleted
- History screen shows complete sync activity

### Decision 3: Update via `createOrUpdateEvent` with existing `eventId`

**Chosen:** Extend `CalendarService.createEvent()` to accept an optional `eventId` parameter. When provided, `device_calendar` treats `createOrUpdateEvent` as an update to the existing event instead of creating a new one.

**Rationale:**
- `device_calendar`'s `createOrUpdateEvent` uses event ID to determine create vs update
- No new plugin methods needed

## Risks / Trade-offs

- **[Risk] Additional API calls per sync**: Each already-synced event requires fetching the target event for comparison, plus a write if changed. → **Mitigation**: Typical calendar has few ongoing events; the extra calls are negligible. The `device_calendar` `retrieveEvents` call returns all events — we already fetch them.
- **[Trade-off] No partial updates**: If only the title changed, the entire event is re-written. → Acceptable; `createOrUpdateEvent` handles this atomically.

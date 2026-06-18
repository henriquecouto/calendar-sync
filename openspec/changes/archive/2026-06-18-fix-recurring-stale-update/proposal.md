## Why

When a recurring event is already synced, the sync engine classifies the merged event against the target. Every sync cycle, the window slides forward and the "earliest" instance advances one day. The instance's `startDate` always differs from the target's → always detects `timeChanged` → triggers UPDATE → ContentObserver fires → loop of repeated sync cycles.

## What Changes

- Add optional `canonical_time` TEXT column to `sync_mappings` (stores `HH:mm` of the first occurrence's start time)
- When creating a target for a recurring event, store the `HH:mm` of the source's start time in the mapping
- When comparing a recurring event for changes, compare only `HH:mm` (ignoring the date) against the stored canonical time
- Revert the "earliest instance" approach — it doesn't solve the underlying window-sliding problem

## Capabilities

### Modified Capabilities

- `event-sync`: Change detection for recurring events SHALL compare only the time-of-day (HH:mm) component of start times, using a stored `canonical_time` in the mapping table

## Impact

- **Sync engine**: `_classifySingle()` — modified time comparison for recurring events; `_execute()` create — store canonical_time
- **Mapping database**: `insertMapping()` — accepts optional `canonicalTime`; `listMappingsForCalendar()` — returns rows including canonical_time
- **Database schema**: add `canonical_time TEXT` column to `sync_mappings` (no schema migration; ALTER TABLE ADD COLUMN in onUpgrade)

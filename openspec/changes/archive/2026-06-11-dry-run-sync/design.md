## Context

CalSync currently syncs events immediately with no preview. Users configure source/target calendars and a sync name, then tap "Sync Now" — events are created, updated, and deleted without confirmation. The sync engine (`SyncEngine.runSync()`) orchestrates detection via the mapping table and writes to both the calendar and the mapping database. There's no way to see what will happen before it happens.

## Goals / Non-Goals

**Goals:**
- Allow users to preview sync results without modifying any data
- Show three categories: would-be-synced, would-be-skipped, and would-be-deleted events
- For would-be-synced events, show what the target event would look like
- Accessible via a dedicated screen navigated from the home page

**Non-Goals:**
- Staging or approving individual events before sync
- Partial dry runs (per-category filtering)
- Persisting dry run results
- Editing sync configuration from the dry run screen

## Decisions

### 1. Refactor `SyncEngine` into classify + execute phases; add `runDryRun()` to the same class

**Rationale**: The current `runSync()` interleaves detection and mutation in a single monolithic method. Copying the detection logic into a separate `DryRunEngine` guarantees drift — any bug fix or behavior change to real sync must be mirrored in two places. Instead, split the engine into two phases:

1. **Classification** (reads only): List source events, load mappings, compare against target events. Produces a `SyncPlan` — a pure data structure describing what would happen (toCreate, toUpdate, toSkip, toDelete, errors).
2. **Execution** (mutations): Iterate the `SyncPlan` and apply calendar/mapping writes.

`runSync()` does both phases (unchanged public API). `runDryRun()` does classification only and returns the `SyncPlan` — no writes anywhere. Both paths share identical classification logic.

A new `SyncPlan` model carries enough context for both audit display (dry run) and deferred execution (real sync): source event data, projected target event fields, mapping IDs, calendar IDs.

**Alternatives considered**:
- Separate `DryRunEngine` class with duplicated logic: Rejected — guaranteed classification drift.
- `dryRun: bool` flag without refactoring: Rejected — the monolithic method is too intertwined to safely flag-off mutations.

### 2. Dry run engine reads mappings but does not write them

The engine calls `MappingDatabase.isEventSynced()` and `MappingDatabase.listMappingsForCalendar()` for detection, exactly as `SyncEngine` does. It never inserts or deletes mappings. This guarantees the dry run accurately reflects what the real sync would detect.

### 3. Dedicated screen (`DryRunScreen`) instead of inline on HomePage

**Rationale**: The dry run output has three categorized lists with event details — too much information to fit in a small status text. A full screen provides room for scrollable lists and clear categorization.

**Navigation**: Via a new icon button on the HomePage AppBar (alongside the existing history button). This keeps the entry point visible but doesn't crowd the main form.

### 4. Result model mirrors sync categories

`DryRunResult` mirrors `SyncResult` structurally:
- `wouldSync` — list of source events that would be created (with a projected target event preview)
- `wouldSkip` — list of source events already mapped
- `wouldDelete` — list of orphaned target events that would be removed

Each item in `wouldSync` includes a `ProjectedEvent` (title, description, start, end) showing what would appear in the target calendar.

### 5. No new dependencies

All data access uses existing `CalendarService`, `MappingDatabase`, and `SettingsService`. No new plugins or packages needed.

## Risks / Trade-offs

- **Stale read risk**: If calendar data changes between the dry run and actual sync, the results will differ. This is inherent to any read-before-write operation. → Mitigation: Display a timestamp on the dry run screen so users know when the snapshot was taken.
- **Large calendar performance**: Listing all events (30-day window) for both source and target could be slow with thousands of events. → Mitigation: The existing 30-day window already bounds this. Add a loading indicator.
- **No partial approval**: Users can't say "sync events A and B, but skip C." → Mitigation: This is a non-goal for v1. Documented as out of scope.

## Open Questions

<!-- None — scope is well-defined -->

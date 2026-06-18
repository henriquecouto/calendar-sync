## Context

Each sync cycle processes recurring event instances that share the same base `eventId`. The merged event uses an instance's `startDate` for classification. As the 30-day fetch window slides forward, the same instance is never seen twice — the "earliest" instance is always one day later. The `startDate` always differs from the target's stored time, causing false `timeChanged`.

## Goals / Non-Goals

**Goals:**
- Eliminate false `timeChanged` for unchanged recurring events
- Preserve time-of-day change detection (e.g., user moves from 10:00 to 14:00)

**Non-Goals:**
- Detecting date-only changes in recurring events (e.g., moving from Monday to Tuesday while keeping 10:00)
- Changing how non-recurring events are classified

## Decisions

### Decision 1: Store canonical time (HH:mm) in mapping

**Choice**: Add `canonical_time TEXT` column to `sync_mappings`. When creating a target for a recurring event, extract `HH:mm` from the source's `startDate` and store it. On subsequent comparisons, compare `HH:mm` against this stored value instead of comparing full `DateTime`.

**Rationale**: The date component always changes as the window slides, but the time-of-day is stable unless the user modifies the recurring event. Storing just `HH:mm` makes the comparison immune to date shifts.

**Alternatives considered**:
- *Earliest instance*: Fails because the earliest instance also advances with the window.
- *Store full timestamp*: Would always mismatch as the window slides.

### Decision 2: No schema version bump

**Choice**: Add the column via `ALTER TABLE ADD COLUMN` in `onUpgrade` but don't bump the version number. The column is optional (nullable) and doesn't affect existing mappings.

**Rationale**: Adding a nullable column via `ALTER TABLE` is a safe, zero-cost migration for SQLite. Existing rows get `NULL` in `canonical_time`.

## Context

The `device_calendar_plus` plugin's `listEvents` returns both recurring base events and their generated instances. For a recurring event, all instances share the same `eventId`. Each instance has a unique `instanceId`. The sync engine currently treats every returned event as independent, creating one target event per source event in the list. For a weekly recurring event with 5 instances in the 30-day window, this results in 5 target events instead of 1.

## Goals / Non-Goals

**Goals:**
- Create exactly 1 target event per recurring source event series (not 1 per instance)
- Skip instances of already-synced recurring events during classification
- Propagate recurrence rule to target so calendar provider manages instances automatically

**Non-Goals:**
- Detecting changes to recurrence rules after initial sync (handled by existing timeChanged/titleChanged logic)
- Handling exception instances (modified single occurrences) differently
- Migrating existing non-recurring target events created from recurring sources

## Decisions

### Decision 1: Handle instances via base event classification

**Choice**: In `_classify()`, when `eventId != instanceId` (this event is an instance), the system fetches the base recurring event by `eventId` and classifies it instead of the instance. If the base is NOT mapped, a merged event is used (instance's start/end times + base's recurrenceRule). If the base IS mapped, the base event is fetched once per sync cycle and classified normally (detecting time/title changes for updates). Instances themselves are never directly classified as CREATE or UPDATE. A `processedIds` set prevents fetching and classifying the same base eventId multiple times per cycle.

**Rationale**: The calendar provider returns instances but may not include the base recurring event in `listEvents`. Fetching the base ensures change detection works even when only instances appear. Using the instance's start/end times avoids the zero-duration issue where the base event has `startDate == endDate`.

### Decision 2: Copy recurrence rule to target

**Choice**: When creating a target for a recurring source event, pass the source's `recurrenceRule` to `CalendarService.createEvent()`. The `device_calendar_plus` plugin already supports `RecurrenceRule? recurrenceRule` as an optional parameter.

**Rationale**: The plugin handles RRULE natively. No custom recurrence logic needed.

### Decision 3: Classify recurring base events same as non-recurring

**Choice**: The base recurring event (where `eventId == instanceId` and `isRecurring == true`) is classified normally: if not mapped → toCreate with recurrence fields; if mapped → compare start/end/title for changes.

**Rationale**: The existing classification logic (isEventSynced, timeChanged, titleChanged) works for recurring base events too. Only the instance skip is new.

## Risks / Trade-offs

- **[RRULE incompatibility]**: Different calendar providers may interpret RRULE differently (timezone handling, BYDAY semantics). → Mitigation: Accept as known limitation; source title preserved in description for debugging.

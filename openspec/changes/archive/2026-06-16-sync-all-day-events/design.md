## Context

The `device_calendar` plugin's `Event` class has an `allDay` boolean property. Currently, the sync engine never reads or sets it. All-day events from the source calendar are created in the target calendar without the `allDay` flag, making them appear as timed events (midnight-to-midnight on consecutive days) instead of proper all-day events.

Additionally, some calendar providers return `null` for the `end` time of all-day events. The current code treats `null` end times as errors or skips them, which would prematurely discard valid all-day events.

## Goals / Non-Goals

**Goals:**
- Propagate `event.allDay` from source event to target event during sync
- Include `allDay` in the change-detection comparison (re-sync when `allDay` status changes)
- Handle all-day target events that have null end times (common on some Android calendar providers)

**Non-Goals:**
- Changing how all-day events are displayed in the UI
- Adding settings to control all-day event behavior
- Modifying the sync window or event filtering logic
- Supporting time-zone-specific all-day event handling beyond what `device_calendar` provides

## Decisions

### 1. Pass `allDay` as a parameter to `CalendarService.createEvent`

Add an optional `bool? allDay` parameter to `createEvent`. When non-null, set it on the `Event` object before calling `createOrUpdateEvent`. This is the simplest change — no new method needed, and the parameter is backwards-compatible with existing callers.

**Alternatives considered:** Creating a separate `createAllDayEvent` method. Rejected — adds unnecessary API surface for a single boolean flag.

### 2. Include `allDay` in `ToCreateEntry` and propagate through `_execute`

`ToCreateEntry` already holds the projected fields for the target event. Adding `projectedAllDay` is consistent with the existing pattern. The `_classify` method reads `event.allDay` and stores it in the entry; `_execute` passes it to `createEvent`.

### 3. Add `allDay` to the change-detection comparison in `_classify`

When a source event is already synced, the engine compares `start`, `end`, and `title` to decide whether an update is needed. Add `allDay` to this comparison so that if a source event's all-day status changes, the target event is updated.

### 4. Relax the null-end-time guard for all-day events

In the orphan-mapping cleanup path (lines 135-139), target events with null `end` times are deleted from the mapping table. For all-day events, a null end time can be valid. Skip this guard when `targetEvent.allDay == true`.

In the change-detection path (lines 183-192), target all-day events with null start/end should not cause a skip. If `allDay` is true and start/end are null, treat the event as needing an update (re-create it).

### 5. Use timed events (allDay=false) instead of allDay=true for target events

The `device_calendar` plugin applies a one-way transformation when reading all-day events on Android (event.dart:130-141):

```
readStart = originalStart + timeZoneOffset(originalStart)
readEnd   = originalEnd   + timeZoneOffset(originalEnd) - 1 day  (exclusive → inclusive)
```

Android's `ContentProvider` also applies its own normalization to `allDay=true` events (rounding DTEND to midnight UTC +1 day), making round-trip fidelity impossible.

**Decision:** For all-day source events, create target events as **timed** (`allDay=false`) in the device's local timezone. The plugin reads source events in UTC, so we convert to local midnight using `DateTime.now().timeZoneOffset`:

```
plugin read (UTC):      start=Jun23 00:00, end=Jun23 00:00 (-1d from original)
our code (local -03):   start=Jun23 03:00 UTC (=Jun23 00:00 local), end=Jun24 03:00 UTC (=Jun24 00:00 local)
target (allDay=false):  DTSTART=Jun23 03:00 UTC, DTEND=Jun24 03:00 UTC  ← timed event, stored verbatim
```

For multi-day events, the last day's midnight is used for end. Tested working in Etar, Google Calendar, and Outlook.

No timezone database initialization needed — uses standard `DateTime` API.

**Single-day:** `start=Jun23 00:00, end=Jun24 00:00` → Etar shows 1 day ✓  
**Multi-day:** `start=Jun23 00:00, end=Jun26 00:00` → Etar shows 3 days ✓

**Alternatives considered:**
- Using `allDay=true` with timezone adjustments — Rejected after extensive testing. Android's ContentProvider normalizes DTEND for all-day events unpredictably across calendar apps.

## Risks / Trade-offs

- **[Risk] Some calendar providers may not support the `allDay` flag on `createOrUpdateEvent`** → The `device_calendar` plugin handles this at the platform level; if the provider rejects it, the operation will fail with a standard error that's already caught and logged.
- **[Risk] Null end times on all-day events could cause false-positives in the orphan-detection path** → Mitigated by checking `allDay` before applying the null-end guard.

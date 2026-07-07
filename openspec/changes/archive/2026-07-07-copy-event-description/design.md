## Context

The sync engine currently builds target event descriptions as:
```
<original title>
---
🔃 Automatically created by CalSync
```

And target events are created without a location field. The source event's own description and location are never carried over. This design adds per-profile toggles to optionally copy both fields.

### Current state
- `SyncProfile` model in `lib/settings/profile_service.dart` has 7 fields.
- `sync_profiles` SQLite table mirrors these fields.
- `CalendarService.createEvent()` accepts `title`, `startDate`, `endDate`, `description`, `isAllDay`, `recurrenceRule` — but **not** `location`.
- `device_calendar_plus` plugin's `createEvent` **does** support `location` as a parameter.
- The profile form UI has separate cards: Profile Name, Calendar Pairing, Event Naming, Schedule.
- Description construction happens inline in `sync_engine.dart:_execute()`.

## Goals / Non-Goals

**Goals:**
- Add `copyDescription` and `copyLocation` booleans per profile, both defaulting to `false`.
- When `copyDescription`: prepend source description to target description (as implemented).
- When `copyLocation`: pass source event's `location` to `CalendarService.createEvent()`.
- Add `location` parameter to `CalendarService.createEvent()`.
- Restructure profile form into Basic/Advanced sections:
  - Basic: profile name, calendar pickers, sync enabled toggle.
  - Advanced (collapsed by default): sync event name, fallback interval, copy location toggle, copy description toggle.
- Handle null/empty source fields gracefully.

**Non-Goals:**
- Copying url, timeZone, attendees, or other extended event fields.
- Configuring which specific fields to copy (multi-select). Simple on/off toggles.
- Retroactively updating already-synced events.

## Decisions

### 1. Two independent boolean fields
**Choice:** Separate `copyDescription` and `copyLocation` columns in `sync_profiles`.

**Rationale:** Each field controls a different target event attribute. Independent toggles let users choose exactly what to copy. Simple and consistent with existing `enabled` pattern.

### 2. Location on target event
**Choice:** Add `String? location` to `CalendarService.createEvent()`, pass it through to `device_calendar_plus`. Sync engine passes `event.location` when `copyLocation` is true, `null` otherwise.

**Rationale:** The plugin already supports it — just needs to be exposed through our service layer. No new plugin or permissions required.

### 3. UI restructure: Basic + Advanced sections
**Choice:** Reorganize form into two sections. Basic always visible. Advanced collapsed by default with an `ExpansionTile`.

```
Basic
├── Profile Name
├── Calendar Pairing (source + target)
└── Sync enabled [toggle]

Advanced ▸
├── Sync Event Name
├── Fallback Interval
├── Copy location    [○]
└── Copy description [○]
```

**Rationale:** Keeps the form clean. Most users don't need to change sync event name or interval after initial setup. Advanced options are discoverable but not in the way.

**Card removals:** The "Event Naming" and "Schedule" standalone cards are removed. Their fields move into Basic (sync enabled) and Advanced (sync event name, fallback interval).

### 4. Database migration
**Choice:** Two separate `ALTER TABLE` statements in the migration chain (`copy_description` already added in v6, `copy_location` added in v7).

**Rationale:** Since v6 is already implemented and deployed (in this change), v7 adds the second column cleanly.

## Risks / Trade-offs

- **[R1] Large descriptions**: Same as before — truncated at 8000 chars. No new risk.
- **[R2] HTML in descriptions**: Same as before — acceptable for v1.
- **[R3] Location field availability**: Not all calendar providers support location. The plugin handles this gracefully (just ignores unknown fields). No crash risk.
- **[R4] UI migration for existing profiles**: The form restructure is purely visual — no data migration needed. Existing fields keep their values, new toggles default to off.

## Open Questions

None.

## Context

The app prevents bidirectional sync loops using a `sync_created_events` table that tracks `(calendar_id, event_id)` for every target event created. This breaks with Outlook/Exchange ActiveSync providers because they reassign `eventId` values when re-syncing events to Exchange and back. The `sync_created_events` entry becomes orphaned (stale `eventId`) and the actual event is no longer recognized as created-by-sync.

The description field, however, is preserved through Exchange sync. By embedding a marker in the description, the app can identify its own events regardless of `eventId` changes.

## Goals / Non-Goals

**Goals:**
- Embed a structured sync marker in every target event's description
- Loop detection checks description marker as primary mechanism (survives `eventId` reassignment)
- Keep `sync_created_events` table as secondary/defense-in-depth (no migration needed)
- Preserve the original event title in the description alongside the marker

**Non-Goals:**
- Removing or migrating the `sync_created_events` table (simplification can be done later)
- Changing the target event title (still uses `syncEventName`)
- Handling manual editing of description by user (acceptable edge case)

## Decisions

### Marker format: simple header at end of description
```
Doctor Appointment
---
🔃 Automatically created by CalSync
```

The original title is the first line, followed by `---` to visually separate the marker. The fixed string "🔃 Automatically created by CalSync" is the reliable token for programmatic detection.

### Detection: description marker as primary, `sync_created_events` as secondary
In `_classifySingle`, check the source event's description for the marker first. If present, skip the event. This catches events whose `eventId` changed after Outlook re-sync. The `sync_created_events` table remains as a fallback for cases where the description might be truncated or empty.

Order in `_classifySingle`:
1. Check description for marker → skip if present
2. Check `sync_created_events` table → skip if present (defense-in-depth)
3. Check mapping table → classify as create/update/skip

### Title change detection unchanged
The marker is appended after the original title. When checking `titleChanged` (comparing `event.title` against `targetEvent.description`), the description now contains extra data. The comparison needs to extract just the original title or compare differently. Since the target event's description is `"Original Title\n---\n..."` and `event.title` (source) is just `"Original Title"`, a direct `event.title != targetEvent.description` will always show as changed.

**Decision:** For UPDATE classification, strip the marker prefix from the target event's description before comparing against the source title. The original title is the first line up to `\n---\n`.

Alternatively, compare using `targetEvent.description.startsWith(event.title)`. Simpler and handles the case correctly since the title ends at the first newline.

Chosen: `targetEvent.description.startsWith(event.title)` — simpler, no string manipulation needed.

### Constant defined in sync_engine.dart
A single constant `_syncMarker = '🔃 Automatically created by CalSync'` defined at the top of `sync_engine.dart`. All creation and detection logic references this constant.

## Risks / Trade-offs

- **Description truncation**: Some calendar providers may truncate long descriptions. If the marker is cut off, loop detection falls back to `sync_created_events` table. Mitigation: keep the marker short and at the end, so title data is preserved.
- **False positive if user's event title contains marker**: Extremely unlikely with "Automatically created by CalSync". No mitigation needed.
- **User manually removes marker from description**: The event would be re-synced on next cycle. Acceptable — user intentionally broke the link.

## Context

The sync engine currently passes only `syncEventName` (title) and the source event's `start`/`end` to `CalendarService.createEvent()`. The source event's original `title` is discarded. The `device_calendar` plugin's `Event` model already supports a `description` field.

## Goals / Non-Goals

**Goals:**
- Set the source event's original title as the `description` of the target event
- `CalendarService.createEvent()` accepts an optional `description` parameter
- `SyncEngine.runSync()` passes `event.title` as the `description` argument

**Non-Goals:**
- Preserving other source event metadata (location, attendees, etc.)
- Updating existing synced events retroactively

## Decisions

### Add optional `description` parameter to `CalendarService.createEvent()`

Current signature:
```dart
Future<String?> createEvent(String calendarId, String title, TZDateTime start, TZDateTime end)
```

New signature:
```dart
Future<String?> createEvent(String calendarId, String title, TZDateTime start, TZDateTime end, {String? description})
```

The `Event` constructor already accepts `description` as a named parameter. The wrapper simply forwards it.

### Pass source title as description in SyncEngine

In the creation pass, `event.title` is passed as the `description:` argument:
```dart
final targetEventId = await _calendarService.createEvent(
  targetCalendarId,
  syncEventName,
  event.start!,
  event.end!,
  description: event.title,
);
```

## Risks / Trade-offs

- [Risk] Very long source event titles overflow the description field. → Mitigation: The calendar provider handles truncation; no special handling needed.
- [Risk] Null source titles produce `null` descriptions. → Mitigation: `device_calendar` handles `null` description gracefully (omits the field).

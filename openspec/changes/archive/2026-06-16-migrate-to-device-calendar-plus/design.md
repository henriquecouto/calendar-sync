## Context

The app currently uses `device_calendar` v4.3.3, a Flutter plugin for reading/writing Android/iOS device calendars. The plugin is unmaintained (last published 20 months ago) and pins `timezone ^0.9.0`, which blocks updates to 5 transitive dependencies. `device_calendar_plus` v0.6.0 is the actively maintained successor, rebuilt from scratch with native `DateTime`, no `timezone` dependency, proper recurring event support, and a cleaner API.

## Goals / Non-Goals

**Goals:**
- Replace `device_calendar` with `device_calendar_plus` in all Dart code
- Remove `timezone` dependency and all `TZDateTime`/`initializeTimezones()` usage
- Preserve identical sync behavior (event creation, update detection, deletion propagation)
- Unblock transitive dependency updates (`meta`, `vector_math`, `matcher`, `test_api`)
- Keep all existing tests passing after migration

**Non-Goals:**
- Adding new features (recurring event sync, attendee sync, etc.)
- Changing the Android/iOS permission XML — `device_calendar_plus` uses the same platform permissions
- Migrating background sync (`workmanager`) — it calls the same `SyncEngine`, updated transitively
- Adding integration tests

## Decisions

### 1. API entry point: `DeviceCalendar.instance` singleton

The old plugin used `DeviceCalendarPlugin()` instances. The new one uses `DeviceCalendar.instance` (singleton). `CalendarService` will hold a `final DeviceCalendar _plugin = DeviceCalendar.instance;` reference.

**Alternatives considered:** Creating a new instance per call — rejected because the plugin's own docs recommend the singleton pattern and it mirrors the old convention.

### 2. Error handling: exceptions instead of `Result<T>`

Old API returned `Result<T>` with `.isSuccess`/`.data`/`.errors`. New API throws typed `DeviceCalendarException` (runtime errors) or `ArgumentError` (programmer errors). `CalendarService` methods will use `try/catch` and return nullable results (`null` on failure), preserving the existing service interface.

**Example:**
```dart
// Old
final result = await _plugin.retrieveCalendars();
if (result.isSuccess && result.data != null) return result.data!.toList();
return [];

// New
try {
  return await _plugin.listCalendars();
} on DeviceCalendarException catch (e) {
  return [];
}
```

### 3. DateTime: `TZDateTime` → native `DateTime`

`device_calendar_plus` uses native `DateTime` (always in local time). All `TZDateTime` references, `TZDateTime.now(local)`, and `local` location imports are replaced with plain `DateTime.now()`.

**Key difference:** Old API used `TZDateTime` requiring explicit timezone initialization. New API DateTime is already in device local time, simplifying all date handling.

### 4. Event model mapping

| Old (`device_calendar`) | New (`device_calendar_plus`) |
|---|---|
| `Event` | `CalendarEvent` |
| `event.eventId` | `event.eventId` (same) |
| `event.title` | `event.title` (same) |
| `event.start` (TZDateTime) | `event.startDate` (DateTime) |
| `event.end` (TZDateTime) | `event.endDate` (DateTime) |
| `event.description` | `event.description` (same) |
| `event.allDay` | `event.isAllDay` |
| `Calendar` | `PlatformCalendar` (readonly), with ID/name/color |

### 5. RetrieveEventsParams removed

Old API used `RetrieveEventsParams(startDate:, endDate:, eventIds:)`. New API has direct method overloads:
- `listEvents(startDate, endDate, {calendarIds})` — list by date range
- `getEvent(eventId)` — single event by instance ID (no calendar ID needed)

### 6. Permission handling: dual approach

The app uses `permission_handler` separately from the calendar plugin. `device_calendar_plus` has built-in `hasPermissions()` / `requestPermissions()`. We keep `permission_handler` for backward compatibility but delegate calendar permission checks to the plugin's own API. `PermissionService` gains a `CalendarPermissionStatus?` bridge so the `PermissionGate` widget can query the plugin directly.

### 7. All-day events preserved as all-day (not converted to timed)

The old `device_calendar` plugin had unreliable all-day event handling, forcing us to convert all-day source events into timed target events (`isAllDay: false`). This required `_localMidnight` and `_projectEnd` helpers to project all-day dates onto midnight boundaries.

`device_calendar_plus` correctly handles all-day events with proper half-open `[startDate, endDate)` intervals. This means we can simply:
- Copy `event.startDate` and `event.endDate` directly as the target dates
- Set `isAllDay: event.isAllDay` on the target
- Remove `_localMidnight` and `_projectEnd` entirely
- Use uniform `millisecondsSinceEpoch` comparison for all change detection (no special all-day branch)

**Rationale:** The timed-event workaround was only needed because the old plugin's all-day support was broken. The new plugin handles all-day natively. Preserving the all-day type on the target event is also semantically correct — if the source blocks a whole day, the target should too, showing as a colored bar rather than occupying the time grid.

**Alternatives considered:** Converting to timed events (the old approach) — rejected because it requires ~30 lines of projection logic that's error-prone (we already caught the `+1` day bug) and produces worse visual results in the target calendar.

### 8. Event creation: no more `Event` constructor

Old API: construct `Event(calendarId, ...)` then call `createOrUpdateEvent(event)`.
New API: call `createEvent(calendarId:, title:, startDate:, endDate:, ...)` with named parameters directly.

## Risks / Trade-offs

- **[Risk] `device_calendar_plus` is v0.6.0 — API may change before 1.0** → Pin exact version `0.6.0` in pubspec, review changelog before upgrading
- **[Risk] Different event ID format across plugins** → Mapping table stores both IDs; old mappings become invalid after migration → Accept that first sync after migration treats all events as new (one-time re-sync)
- **[Risk] All-day event semantics differ** → Old plugin forced timed-event workaround. New plugin handles all-day natively. Verified on device: all-day events sync correctly with `isAllDay: true`, dates passed through without projection. The workaround (timed conversion) is removed.
- **[Risk] Plugin may not handle edge cases the old one did** → Comprehensive manual testing on Android device before release

## Open Questions

- Should we add a migration path for old mapping table entries, or accept a clean re-sync? **Decision: accept clean re-sync.** The mapping table uses source event IDs which remain valid; target event IDs will change but the old ones are deleted on first sync anyway via orphan detection.

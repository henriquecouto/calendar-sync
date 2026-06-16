## Why

The `device_calendar` plugin (v4.3.3) has been unmaintained for 20 months. Its dependency on `timezone ^0.9.0` blocks updates to `timezone`, `meta`, `vector_math`, `matcher`, and `test_api`. `device_calendar_plus` is the actively maintained successor — rewritten from scratch with native `DateTime` handling, proper recurring event support, and no `timezone` dependency.

## What Changes

- Replace `device_calendar: ^4.3.3` with `device_calendar_plus: ^0.6.0` in `pubspec.yaml`
- Remove `timezone: ^0.9.4` from dev_dependencies (no longer needed)
- **BREAKING**: Rewrite `CalendarService` — different class names (`DeviceCalendar` instead of `DeviceCalendarPlugin`), different method signatures, different error model (exceptions instead of result wrappers)
- **BREAKING**: Rewrite `SyncEngine` — remove all `TZDateTime` usage, replace `package:device_calendar/device_calendar.dart` types with `package:device_calendar_plus/device_calendar_plus.dart` equivalents
- Update `PermissionService` to align with `device_calendar_plus` permission API
- Remove `import 'package:timezone/timezone.dart'` and `initializeTimezones()` call
- Update calendar-access and permission-handling specs to reflect new API contracts

## Capabilities

### New Capabilities

None. This is a dependency replacement — no new user-facing features.

### Modified Capabilities

- `calendar-access`: Event model changes (`Event` → `CalendarEvent` from new plugin), method signatures change (no more `RetrieveEventsParams`), error handling changes (exceptions instead of `Result` wrappers)
- `permission-handling`: Permission checking aligns with `device_calendar_plus` built-in permission API (`hasPermissions()`, `requestPermissions()` returning `CalendarPermissionStatus`)

## Impact

- `pubspec.yaml`: dependency swaps, transitive dep updates unlocked (`meta`, `vector_math`, `matcher`, `test_api`)
- `lib/calendar/calendar_service.dart`: full rewrite (~60 lines)
- `lib/sync/sync_engine.dart`: full rewrite of date/time handling and type imports (~200 lines changed)
- `lib/permissions/permission_service.dart`: minor updates to align with new permission model
- `lib/main.dart`: remove `timezone` initialization
- All tests in `test/` using `device_calendar` types need updating
- `android/app/src/main/AndroidManifest.xml`: verify permissions still declared (no change expected)

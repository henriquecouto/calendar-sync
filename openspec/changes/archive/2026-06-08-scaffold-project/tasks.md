## 1. Project Scaffold

- [x] 1.1 Run `flutter create --platforms android .` to generate the Flutter project skeleton
- [x] 1.2 Add `device_calendar`, `sqflite`, `permission_handler`, and `shared_preferences` to `pubspec.yaml`
- [x] 1.3 Run `flutter pub get` and verify no dependency resolution errors
- [x] 1.4 Add `READ_CALENDAR` and `WRITE_CALENDAR` entries to `android/app/src/main/AndroidManifest.xml`

## 2. Permission Handling (`lib/permissions/`)

- [x] 2.1 Implement `PermissionService` that checks and requests `calendar` permissions via `permission_handler`
- [x] 2.2 Handle "permanently denied" state by opening the system Settings app intent
- [x] 2.3 Create a `PermissionGate` widget that blocks child widgets until permissions are granted

## 3. App Settings (`lib/settings/`)

- [x] 3.1 Implement `SettingsService` wrapping `shared_preferences` with keys for source calendar ID, target calendar ID, and sync event name
- [x] 3.2 Expose save/load/clear methods for each individual setting

## 4. Calendar Access (`lib/calendar/`)

- [x] 4.1 Implement `CalendarService` with `listCalendars()` that returns parsed calendar objects (id, name, account)
- [x] 4.2 Implement `listEvents(calendarId)` that fetches events within a configurable time window using `device_calendar`
- [x] 4.3 Implement `createEvent(calendarId, title, start, end)` that creates an event and returns the new event ID
- [x] 4.4 Implement `deleteEvent(calendarId, eventId)` for future sync cleanup

## 5. Sync Engine (`lib/sync/`)

- [x] 5.1 Implement `MappingDatabase` with the SQLite schema (sync_mappings table) using `sqflite`, including UNIQUE constraint
- [x] 5.2 Implement `SyncEngine.runSync(sourceCal, targetCal, syncName)` that lists source events, queries mappings, creates target events for unsynced ones, and inserts new mappings
- [x] 5.3 Ensure idempotency: running sync twice with the same events produces no duplicates

## 6. App Entrypoint (`lib/main.dart`)

- [x] 6.1 Wire `PermissionGate` as the root widget that gates the rest of the app
- [x] 6.2 Wire `SettingsService` and `CalendarService` as simple stateful dependencies (no DI framework needed)
- [x] 6.3 Wire `SyncEngine` to read settings and trigger sync on user action

## 7. Quality Gates

- [x] 7.1 Run `flutter analyze` and fix all warnings and errors
- [x] 7.2 Add a smoke test in `test/` that verifies `SettingsService` rounds-trips values
- [x] 7.3 Run `flutter test` and confirm all tests pass
- [x] 7.4 Run `flutter build apk --debug` and confirm no build errors

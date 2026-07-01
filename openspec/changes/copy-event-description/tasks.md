## 1. Database Schema

- [x] 1.1 Add `copy_description INTEGER NOT NULL DEFAULT 0` column to `sync_profiles` table in `lib/sync/database_provider.dart` (onCreate and onUpgrade)
- [x] 1.2 Increment database version and add migration path in `onUpgrade` (v5→v6 for copy_description)
- [x] 1.3 Add `copy_location INTEGER NOT NULL DEFAULT 0` column to `sync_profiles` table and migration v6→v7

## 2. Model Changes

- [x] 2.1 Add `bool copyDescription` field to `SyncProfile` class in `lib/settings/profile_service.dart`
- [x] 2.2 Update `SyncProfile.copyWith()` to include the new `copyDescription` parameter
- [x] 2.3 Add `bool copyLocation` field to `SyncProfile` and `copyWith()`

## 3. ProfileService CRUD

- [x] 3.1 Update `createProfile()` to accept and persist `copyDescription`
- [x] 3.2 Update `updateProfile()` to write `copyDescription` to the database
- [x] 3.3 Update `listProfiles()` / `getProfile()` to read `copyDescription` from query results and deserialize into the model
- [x] 3.4 Update `createProfile()` to accept and persist `copyLocation`
- [x] 3.5 Update `updateProfile()` to write `copyLocation`
- [x] 3.6 Update `_rowToProfile()` to read `copyLocation`

## 4. CalendarService

- [x] 4.1 Add optional `String? location` parameter to `CalendarService.createEvent()` in `lib/calendar/calendar_service.dart`
- [x] 4.2 Pass `location` through to `device_calendar_plus` `createEvent` call

## 5. Profile Form UI — Basic/Advanced Restructure

- [x] 5.1 Remove "Event Naming" and "Schedule" standalone cards from `lib/screens/profile_config_screen.dart`
- [x] 5.2 Add Basic section with profile name, calendar pickers, and sync enabled toggle (from "Schedule")
- [x] 5.3 Add Advanced section (`ExpansionTile`, collapsed by default) containing sync event name, fallback interval, copy location, and copy description toggles
- [x] 5.4 Update `_load()` to restore `copyLocation` from profile
- [x] 5.5 Pass `copyLocation` value when saving (create and edit paths)

## 6. Sync Engine

- [x] 6.1 Extract description building into `buildDescription()` helper in `lib/sync/sync_engine.dart`
- [x] 6.2 Pass `copyDescription` from profile to `runSync` and `_execute` on create/update paths
- [x] 6.3 Add `copyLocation` parameter to `runSync` and `_execute`
- [x] 6.4 Pass `event.location` (or null) to `createEvent` based on `copyLocation` on create and update paths

## 7. Callers

- [x] 7.1 Update `lib/background/sync_task.dart` to pass `profile.copyLocation` to `runSync`
- [x] 7.2 Update `lib/screens/dashboard_screen.dart` to pass `profile.copyLocation` to `runSync`

## 8. Tests

- [x] 8.1 Add unit tests for `buildDescription` with all combinations
- [x] 8.2 Add sync engine tests for `copyDescription: true` create path
- [x] 8.3 Add sync engine tests for `copyLocation: true` create/update paths
- [x] 8.4 Run `flutter test` and verify all tests pass
- [x] 8.5 Run `flutter analyze` and fix any warnings

## 9. Verification

- [x] 9.1 Build debug APK (`flutter build apk --debug`) and verify no compilation errors

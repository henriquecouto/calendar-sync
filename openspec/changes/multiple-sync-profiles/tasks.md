## 1. Data Layer Foundation

- [x] 1.1 Add `uuid` package dependency to `pubspec.yaml`
- [x] 1.2 Create `ProfileService` class in `lib/settings/profile_service.dart` with `sync_profiles` table schema (id, name, source_calendar_id, target_calendar_id, event_name, interval_minutes, enabled) and CRUD methods. Include UNIQUE constraint on `name` column.
- [x] 1.3 Add DB schema migration v3→v4 in `MappingDatabase._init()` — `onUpgrade` adds `profile_id TEXT` columns to `sync_mappings` and `sync_status` with DEFAULT empty string. Also creates `sync_created_events` table with UNIQUE(calendar_id, event_id).
- [x] 1.4 Update `MappingDatabase` methods (`isEventSynced`, `insertMapping`, `listMappingsForCalendar`) to accept and filter by `profileId`
- [x] 1.5 Update `MappingDatabase.insertStatus()` to accept `profileId` parameter
- [x] 1.6 Add `isEventCreatedBySync(calendarId, eventId)`, `insertCreatedEvent(calendarId, eventId)`, and `deleteCreatedEvent(calendarId, eventId)` methods to `MappingDatabase`
- [x] 1.7 Implement one-time settings migration in `main.dart` or `ProfileService`: detect old SharedPreferences keys, create default profile named `"Default"`, set migration flag
- [x] 1.8 Deprecate `SettingsService` — keep for migration only, mark methods as deprecated

## 2. Sync Loop Prevention

- [x] 2.1 In `SyncEngine._classify()`, before classifying each source event, check `sync_created_events` — if event was created by sync, add to `toSkip`
- [x] 2.2 In `SyncEngine._execute()` create path, after successfully creating a target event, insert into `sync_created_events`
- [x] 2.3 In `SyncEngine._execute()` delete path, after deleting a target event, remove from `sync_created_events`
- [x] 2.4 In `SyncEngine._execute()` update path, after replacing a target event, delete old entry and insert new entry in `sync_created_events`
- [x] 2.5 In `ProfileService.deleteProfile()`, remove `sync_created_events` entries for all target events created by that profile's mappings

## 3. Sync Engine Updates

- [x] 3.1 Add `profileId` parameter to `SyncEngine.runSync()` and `SyncEngine.runDryRun()`
- [x] 3.2 Pass `profileId` through to all `MappingDatabase` calls inside sync engine (`_classify`, `_execute`, `_processOrphanMappings`)
- [x] 3.3 Pass `profileId` through to `MappingDatabase.insertMapping()` and `insertStatus()` calls

## 4. Background Sync Updates

- [x] 4.1 Update `sync_task.dart` callback to load enabled profiles from `ProfileService`, iterate, and run sync for each with individual error handling
- [x] 4.2 Add per-profile status logging in background task (each profile gets its own `insertStatus` call with `profileId`)
- [x] 4.3 Update periodic Workmanager task registration to use minimum interval across enabled profiles
- [x] 4.4 Register/cancel periodic task on profile CRUD changes (create, edit interval, delete, enable/disable)
- [x] 4.5 Update `_signalDone()` to write after all profiles complete

## 5. UI: Profile Config Screen

- [x] 5.1 Refactor `ProfileConfigScreen` to accept optional `profileId` parameter — create mode (null) vs edit mode (existing ID)
- [x] 5.2 Wire create mode to `ProfileService.createProfile()`
- [x] 5.3 Wire edit mode to `ProfileService.updateProfile()`
- [x] 5.4 Add delete action with confirmation dialog calling `ProfileService.deleteProfile()`
- [x] 5.5 Add validation: empty event name rejection, same source+target rejection, duplicate source+target pair rejection, duplicate name rejection
- [x] 5.6 Add profile name text field to config screen (mandatory, unique). Auto-generate name from calendars if left empty on save (format: "Source → Target")
- [x] 5.7 Update profile save to generate UUID via `uuid` package

## 6. UI: Dashboard Screen

- [x] 6.1 Refactor `DashboardScreen` to load profiles from `ProfileService` and render a list of `ProfileCard` widgets
- [x] 6.2 Update `ProfileCard` widget to accept a profile model and display the profile name as title, with source→target calendar names as subtitle. Support per-profile enable toggle callback
- [x] 6.3 Wire per-profile enable/disable toggle on `ProfileCard` to `ProfileService`
- [x] 6.4 Update "Sync All" button to iterate enabled profiles and run `SyncEngine.runSync()` for each with `profileId`
- [x] 6.5 Update "Dry Run" button to pass selected profile or prompt for profile selection
- [x] 6.6 Update "Create Profile" empty state to navigate to `ProfileConfigScreen` without profile ID
- [x] 6.7 Show warning indicator on profile cards with missing calendars

## 7. UI: Sync Status Screen

- [x] 7.1 Add `profileId` to status entry model and update `getStatusHistory()` to optionally filter by `profileId`
- [x] 7.2 Add profile filter dropdown to `SyncStatusScreen` (list of profiles + "All profiles" option)
- [x] 7.3 Display profile name on each status row. Join with `sync_profiles` table or look up by `profile_id`
- [x] 7.4 Handle legacy status rows without `profileId` (show "Unknown profile")
- [x] 7.5 Update status row capping to be per-profile (20 rows per profile)

## 8. UI: Dry Run Screen

- [x] 8.1 Update `DryRunScreen` to accept and require a `profileId` parameter
- [x] 8.2 Update dry run to pass `profileId` through to `SyncEngine.runDryRun()`

## 9. Integration & Cleanup

- [x] 9.1 Run `flutter analyze` and fix all lint issues
- [x] 9.2 Run `flutter test` and ensure existing tests pass or are updated
- [x] 9.3 Verify migration path: install old version, configure sync, upgrade to new version, confirm default profile created
- [x] 9.4 Verify multi-profile isolation: create 2 profiles with same source calendar, sync both, confirm independent mappings
- [x] 9.5 Verify sync loop prevention: create bidirectional profiles (e.g., Work↔Personal), sync both, confirm no duplicate events

## 10. New Unit Tests

### 10.1 Sync Engine — Sync Loop Prevention

- [x] 10.1.1 Event in `sync_created_events` is skipped (`isEventCreatedBySync=true`)
- [x] 10.1.2 Event NOT in `sync_created_events` is classified normally (create/update/skip based on mapping)
- [x] 10.1.3 After CREATE, `sync_created_events` contains the target event
- [x] 10.1.4 After DELETE (orphan), `sync_created_events` no longer contains the target
- [x] 10.1.5 After UPDATE (replace), old entry removed and new entry inserted in `sync_created_events`
- [x] 10.1.6 Bidirectional scenario: profile A→B creates event in B, profile B→A scans B → skips event

### 10.2 Sync Engine — Profile-scoped Mappings

- [x] 10.2.1 Same source event synced by 2 profiles → independent mapping rows
- [x] 10.2.2 `listMappingsForCalendar` does not return mappings from another profile
- [x] 10.2.3 `isEventSynced` returns false for different profile on same source event

### 10.3 Profile Service CRUD

- [x] 10.3.1 `createProfile` returns `SyncProfile` with UUID and correct fields
- [x] 10.3.2 `listProfiles` returns all profiles ordered by name
- [x] 10.3.3 `getProfile` returns specific profile by ID
- [x] 10.3.4 `updateProfile` persists field changes
- [x] 10.3.5 `deleteProfile` removes the profile

### 10.4 Profile Service — Validation

- [x] 10.4.1 `isNameTaken` → true for existing name
- [x] 10.4.2 `isNameTaken` → false for new name
- [x] 10.4.3 `isNameTaken` with `excludeId` ignores own profile (edit scenario)
- [x] 10.4.4 `isSourceTargetPairTaken` → true for existing pair
- [x] 10.4.5 `isSourceTargetPairTaken` → false for reverse direction
- [x] 10.4.6 `isSourceTargetPairTaken` with `excludeId` ignores own profile

### 10.5 Profile Service — Filters & Cascade

- [x] 10.5.1 `listEnabledProfiles` returns only `enabled=true`
- [x] 10.5.2 `deleteProfile` removes mappings from that profile
- [x] 10.5.3 `deleteProfile` removes status entries from that profile
- [x] 10.5.4 `deleteProfile` removes `sync_created_events` for that profile's target events
- [x] 10.5.5 `deleteProfile` does NOT remove `sync_created_events` from other profiles

### 10.6 Mapping Database — Status History

- [x] 10.6.1 `insertStatus` with `profileId` persists correctly
- [x] 10.6.2 `getStatusHistory` filtered by `profileId` returns only that profile
- [x] 10.6.3 `getStatusHistory` without filter returns all profiles
- [x] 10.6.4 Status capped at 20 rows per profile (not global)
- [x] 10.6.5 Legacy rows without `profile_id` handled gracefully

### 10.7 Sync Scheduler

- [x] 10.7.1 No enabled profiles → periodic task cancelled
- [x] 10.7.2 Minimum interval across profiles used as task frequency
- [x] 10.7.3 All profiles have interval=0 → task cancelled

## 1. Setup

- [x] 1.1 Add `workmanager` dependency to `pubspec.yaml`
- [x] 1.2 Run `flutter pub get` and verify no dependency resolution errors

## 2. Settings Service Updates

- [x] 2.1 Add `sync_interval_minutes` key and getter to `SettingsService` (default: 60)
- [x] 2.2 Add `setSyncIntervalMinutes` and `clearSyncIntervalMinutes` methods

## 3. Sync Engine — Delete Propagation

- [x] 3.1 Add `listMappingsForCalendar(sourceCalendarId)` to `MappingDatabase`
- [x] 3.2 Add `deleteMapping(id)` to `MappingDatabase`
- [x] 3.3 Update `SyncEngine.runSync()`: before creation pass, run deletion pass — for each mapping where source event no longer exists, delete target event and remove mapping row
- [x] 3.4 Add deleted count to `SyncResult`

## 4. Background Task — Dart Side (`lib/background/`)

- [x] 4.1 Create `lib/background/sync_task.dart` with top-level `callbackDispatcher()` function
- [x] 4.2 Implement sync logic: read settings, check interval > 0, check permissions, run SyncEngine (with delete handling), catch all errors

## 5. Task Registration — Dart Side

- [x] 5.1 In `main()`, call `Workmanager().initialize(callbackDispatcher)` before `runApp()`
- [x] 5.2 Register periodic fallback task (`calendar_sync_periodic`) with frequency from settings
- [x] 5.3 Re-register periodic task when user changes interval (or cancel if set to 0)

## 6. ContentObserver — Native Kotlin Side

- [x] 6.1 Create `android/app/src/main/kotlin/.../CalendarContentObserver.kt` extending `ContentObserver`
- [x] 6.2 Register observer on `CalendarContract.Events.CONTENT_URI` with `notifyForDescendants = true`
- [x] 6.3 Implement `scheduleSyncWork()`: build `OneTimeWorkRequest` using plugin's `BackgroundWorker::class.java`, 5s initial delay, `REPLACE` policy, task name `syncTask`
- [x] 6.4 Call `CalendarContentObserver.register(context)` during app initialization (via MethodChannel or in `MainActivity`)

## 7. UI Updates (`lib/main.dart`)

- [x] 7.1 Add interval picker (dropdown: 0=off, 15, 30, 60, 120, 360 minutes)
- [x] 7.2 Display note that reactive sync fires within seconds; interval applies to fallback only
- [x] 7.3 Save interval via `SettingsService` on change and update WorkManager registration

## 8. Quality Gates

- [x] 8.1 Run `flutter analyze` and fix all warnings and errors
- [x] 8.2 Run `flutter test` and confirm existing tests still pass
- [x] 8.3 Run `flutter build apk --debug` and confirm no build errors

## 1. Native Soft-Delete Plugin

- [x] 1.1 Create `SoftDeletePlugin.kt` implementing `FlutterPlugin` + `MethodChannel.MethodCallHandler`
- [x] 1.2 Implement soft-delete logic: look up calendar account, build sync-adapter URI, set DELETED=1 + DIRTY=1 with WHERE clause
- [x] 1.3 Add `ContentResolver.requestSync()` for all accounts after marking deletion

## 2. Build Integration

- [x] 2.1 Add Gradle task `injectSoftDeletePlugin` to `android/app/build.gradle.kts`
- [x] 2.2 Configure task to run after Kotlin compilation, injecting plugin registration into `GeneratedPluginRegistrant.java`
- [x] 2.3 Add guard to prevent duplicate injection on repeated builds

## 3. Calendar Service Changes

- [x] 3.1 Add `CalendarDeleteResult` class with `success` and `usedSoftDelete` fields
- [x] 3.2 Change `deleteEvent` return type from `Future<bool>` to `Future<CalendarDeleteResult>`
- [x] 3.3 Call soft-delete MethodChannel first; fall back to plugin's hard-delete on failure

## 4. Sync Engine Changes

- [x] 4.1 Remove `getEvent(sourceEventId)` re-verification from `_processOrphanMappings`
- [x] 4.2 Update `_execute` delete loop to use `CalendarDeleteResult`
- [x] 4.3 Add 5-second post-deletion verification for hard-delete fallback (preserve mapping if event returned)

## 5. Tests

- [x] 5.1 Update mock `deleteEvent` return values to `CalendarDeleteResult`
- [x] 5.2 Update "recent event with source exists" test to expect deletion instead of re-classification
- [x] 5.3 Update "all-day target with far-future end" test to expect deletion instead of re-classification
- [x] 5.4 Remove unused `getEvent('src-1')` mocks from orphan detection tests
- [x] 5.5 Run full test suite and verify 58/58 pass

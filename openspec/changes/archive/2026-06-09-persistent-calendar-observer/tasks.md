## 1. Create persistent JobService

- [x] 1.1 Create `CalendarSyncJobService.kt` in `android/app/src/main/kotlin/dev/henriquecouto/calsync/`
- [x] 1.2 Implement `onStartJob()` to enqueue a one-off WorkManager task with tag `calendar_sync_reactive` and `ExistingWorkPolicy.REPLACE`
- [x] 1.3 Implement `onStopJob()` to return `true` (reschedule on stop)
- [x] 1.4 Configure JobInfo with `TriggerContentUri` on `CalendarContract.Events.CONTENT_URI` and 5-second `triggerContentUpdateDelay`
- [x] 1.5 Declare the JobService in `AndroidManifest.xml` with `android:permission="android.permission.READ_CALENDAR"`

## 2. Remove old observer components

- [x] 2.1 Delete `CalendarContentObserver.kt`
- [x] 2.2 Delete `ObserverRegistrationWorker.kt`

## 3. Simplify MainActivity

- [x] 3.1 Remove `CalendarContentObserver.register(applicationContext)` call
- [x] 3.2 Remove `FlutterEngineHolder.appContext = applicationContext` assignment
- [x] 3.3 Remove `FlutterEngineHolder.binaryMessenger` assignment
- [x] 3.4 Remove `scheduleObserverRegistration()` call and method
- [x] 3.5 Remove `cleanUpFlutterEngine` override (or simplify to super only)

## 4. Cancel existing periodic observer registration work

- [x] 4.1 In `MainActivity.onCreate()`, call `WorkManager.getInstance().cancelUniqueWork("observer_registration")` to clean up any previously scheduled observer re-registration

## 5. Move notification display to Dart sync path

- [x] 5.1 Add native notification display code in `CalendarSyncJobService.kt` that reads `pending_sync_notification` from SharedPreferences after a 10s delay, shows the notification, and clears the key (migrated from `CalendarContentObserver.showPendingNotification()`)
- [x] 5.2 Remove `showPendingNotification()` from old observer
- [x] 5.3 Ensure the Dart-side `sync_task.dart` still writes `pending_sync_notification` to SharedPreferences on sync completion

## 6. Verify

- [x] 6.1 Run `flutter analyze` and fix any issues
- [x] 6.2 Build debug APK and test on emulator: create a calendar event while app is closed, wait ~5s, open app and verify sync ran
- [x] 6.3 Verify ObserverRegistrationWorker is no longer scheduled: `adb shell dumpsys jobscheduler | grep calsync`
- [x] 6.4 Verify new JobService appears in dumpsys with content trigger

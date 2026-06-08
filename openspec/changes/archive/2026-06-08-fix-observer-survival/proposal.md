## Why

The ContentObserver is registered once in `MainActivity.onCreate()` and dies when Android kills the app process. The periodic WorkManager task still runs, but the observer is gone — so reactive sync stops working until the user manually opens the app.

## What Changes

- Add a native `WorkManager Worker` that re-registers the `CalendarContentObserver`
- Schedule it at app start (alongside the existing periodic sync task)
- The observer is revived every time the periodic WorkManager task runs, closing the gap

## Capabilities

### Modified Capabilities

- `background-sync`: The ContentObserver registration now survives process death by being re-registered from a native WorkManager periodic task.

## Impact

- New file: `android/.../ObserverRegistrationWorker.kt`
- Modified: `MainActivity.kt` (schedule the new periodic task)

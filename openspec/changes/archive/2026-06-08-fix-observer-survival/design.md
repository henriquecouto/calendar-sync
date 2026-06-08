## Context

The ContentObserver dies when Android kills the app process. WorkManager tasks survive process death. We can leverage a native Worker to re-register the observer periodically.

## Goals

- ContentObserver re-registers automatically after process death
- No user interaction required

## Decisions

Create `ObserverRegistrationWorker.kt` — a native `androidx.work.Worker` that calls `CalendarContentObserver.register()`. Schedule it at app start as a periodic task (15-minute interval, minimum viable) alongside the existing Flutter sync task. Add `androidx.work:work-runtime-ktx` as a direct dependency to the app module.

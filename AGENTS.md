# AGENTS.md — Calendar Sync (Android)

## Overview
Android app that synchronizes events across multiple **local** device calendars.

## Core Behavior
- When an event appears in **calendar 1**, a corresponding event is created in **calendar 2**.
- The synced event uses a **user-provided name** (not the original event name).
- The app must detect whether an event is **already synced** to avoid duplicates.

## Tech Stack
- **Flutter** (Dart) targeting Android
- **Gradle** for builds (CLI only, no Android Studio assumption)
- Use the `device_calendar` Flutter plugin for local calendar access

## Build / Run Commands
```bash
flutter pub get              # install dependencies
flutter analyze              # lint / static analysis
flutter test                 # run unit/widget tests
flutter build apk --debug    # debug APK
flutter build apk --release  # release APK
```

## Gotchas
- `device_calendar` requires runtime permissions (`READ_CALENDAR` / `WRITE_CALENDAR`). Permission flow must be handled before any calendar operation.
- Calendar IDs and event IDs are **per-provider** — the same event may have different IDs across calendar accounts. Do not rely on ID equality for sync detection.
- Sync detection should use a **local mapping table** (persisted on device) that tracks `(source_event_id, source_calendar_id) → (target_event_id, target_calendar_id)`.

## Conventions
- Prefer `flutter` CLI commands over IDE wrappers.
- Run `flutter analyze` before committing.
- Keep platform-specific code in `android/`; keep Dart logic in `lib/`.

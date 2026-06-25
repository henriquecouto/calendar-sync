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
flutter build apk --debug    # debug APK (fdroid flavor)
flutter build apk --release  # release APK (fdroid flavor)
```

## Build Flavors

The app has two product flavors:

| Flavor  | Application ID                      | Distribution |
|---------|-------------------------------------|-------------|
| fdroid  | `dev.henriquecouto.calsync`         | F-Droid     |
| gplay   | `dev.henriquecouto.calsync_gplay`   | Google Play |

The `fdroid` flavor is the default (no `--flavor` needed). The `gplay` flavor requires `--flavor gplay`:

```bash
flutter build apk --release --flavor gplay          # gplay APK
flutter build appbundle --release --flavor gplay    # gplay AAB (for Play Store)
flutter build apk --release --split-per-abi         # fdroid per-ABI APKs
```

## Release

Releases are managed via GitHub Actions (`.github/workflows/release.yml`):

- **Automatic**: On push to `main`, builds fdroid APKs + gplay APK + gplay AAB and creates a GitHub Release.
- **Manual Play Store upload**: Trigger `workflow_dispatch` in GitHub Actions UI, select a track (`internal`, `alpha`, `beta`, `production`).

### Local Play Store upload (via Fastlane)

Prerequisites:
- Ruby + Bundler installed (`ruby-devel` package on Fedora)
- Google Play service account JSON key

```bash
bundle install                                    # install Fastlane
bundle exec fastlane deploy track:internal        # build + upload
```

## Gotchas
- `device_calendar` requires runtime permissions (`READ_CALENDAR` / `WRITE_CALENDAR`). Permission flow must be handled before any calendar operation.
- Calendar IDs and event IDs are **per-provider** — the same event may have different IDs across calendar accounts. Do not rely on ID equality for sync detection.
- Sync detection should use a **local mapping table** (persisted on device) that tracks `(source_event_id, source_calendar_id) → (target_event_id, target_calendar_id)`.

## Conventions
- Prefer `flutter` CLI commands over IDE wrappers.
- Run `flutter analyze` before committing.
- Keep platform-specific code in `android/`; keep Dart logic in `lib/`.

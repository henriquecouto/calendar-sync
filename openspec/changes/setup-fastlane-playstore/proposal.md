## Why

Currently the release pipeline builds APK/AAB artifacts and publishes them as GitHub Releases, but uploading to the Google Play Store remains a manual step. Automating Play Store upload with Fastlane eliminates a manual, error-prone step and enables continuous delivery to beta/production tracks.

Additionally, the app is distributed via both F-Droid (`dev.henriquecouto.calsync`) and Google Play (`dev.henriquecouto.calsync_gplay`). These channels need different application IDs because each store uses its own signing mechanism. Android build flavors provide the cleanest way to produce separate artifacts from a single codebase.

## What Changes

- Add Android product flavors: `fdroid` (applicationId `dev.henriquecouto.calsync`) and `gplay` (applicationId `dev.henriquecouto.calsync_gplay`)
- Rename MethodChannel from `dev.henriquecouto.calsync/calendar` to `calsync/calendar` (flavor-independent name) in both Dart and Kotlin
- Create `Gemfile` with Fastlane dependency
- Create `fastlane/Appfile` with the gplay package name and Play Store JSON key path
- Create `fastlane/Fastfile` with `deploy` lane using `--flavor gplay` for build
- Update `.gitignore` to exclude Fastlane-generated temporary files and sensitive credentials
- Extend the CI release workflow to build both flavors (fdroid APKs + gplay APK + gplay AAB) and provide a manual `workflow_dispatch` trigger for Play Store upload
- **BREAKING**: None

## Capabilities

### New Capabilities

- `build-flavors`: Configure Android product flavors (`fdroid` and `gplay`) with distinct application IDs, enabling separate distribution channels from a single codebase
- `fastlane-playstore-upload`: Configure Fastlane for automated Play Store builds and uploads, including lane definitions, app metadata integration, and CI integration

### Modified Capabilities

- `release-pipeline`: Extend the GitHub Actions workflow to build per-flavor artifacts and optionally upload the gplay AAB to Play Store via Fastlane

## Impact

- New files: `Gemfile`, `Gemfile.lock`, `fastlane/Appfile`, `fastlane/Fastfile`, `openspec/specs/build-flavors/spec.md`
- Modified files: `android/app/build.gradle.kts` (productFlavors), `lib/calendar/calendar_service.dart` (MethodChannel name), `android/app/src/main/kotlin/dev/henriquecouto/calsync/SoftDeletePlugin.kt` (MethodChannel name), `.gitignore` (Fastlane exclusions), `.github/workflows/release.yml` (flavor-aware builds + dispatch trigger)
- Dependencies: Ruby + Bundler, Fastlane gem, built-in `supply`
- Kotlin package (`dev.henriquecouto.calsync`) remains unchanged — only `applicationId` differs per flavor
- ProGuard rules, AndroidManifest, WorkManager callbacks remain valid as-is
- Existing Play Store metadata at `fastlane/metadata/android/` remains unchanged and is consumed by Fastlane `supply`
- Release signing keystore and `key.properties` already exist, shared across flavors

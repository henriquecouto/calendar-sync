## Context

The project already has a GitHub Actions release pipeline that builds APK/AAB artifacts and publishes them as GitHub Releases on push to `main`. The `fastlane/metadata/android/` directory already contains Play Store metadata (descriptions, changelogs, screenshots) structured exactly as Fastlane `supply` expects. Release signing is configured via `key.properties` and `release.keystore`, with secrets stored in GitHub Actions for CI.

The app is distributed via two channels: F-Droid (open-source, signed by F-Droid) and Google Play (signed by the developer). These channels require different application IDs because F-Droid re-signs with its own key. The Play Store listing was registered with `dev.henriquecouto.calsync_gplay` while F-Droid already publishes `dev.henriquecouto.calsync`.

## Goals / Non-Goals

**Goals:**
- Configure Android product flavors (`fdroid` and `gplay`) with distinct application IDs, sharing a single codebase
- Use a flavor-independent MethodChannel name (`calsync/calendar`) to avoid per-flavor Dart/Kotlin duplication
- Provide a `Fastfile` with lanes to build the gplay AAB and upload to any Play Store track
- Configure `Appfile` to identify the app by gplay package name and service account key
- Add a `Gemfile` to manage Ruby dependencies (Fastlane + plugins)
- Integrate the Fastlane upload as an optional manual step (workflow_dispatch) in the existing release workflow
- Build all artifacts in CI: fdroid APKs, gplay APK, gplay AAB
- Keep existing metadata directory (`fastlane/metadata/android/`) working as-is with `supply`

**Non-Goals:**
- Changing the Kotlin source package (`dev.henriquecouto.calsync`) — flavor changes only affect `applicationId`
- Automatically uploading on every push to `main` — that remains a manual decision via workflow dispatch
- Generating new Play Store metadata from scratch (metadata already exists)
- Creating a Google Play service account or configuring the Google Play Console (that's a prerequisite)
- Managing internal testing tracks or staged rollout percentages (out of scope, but lane structure supports it)

## Decisions

**Decision 1: Use `fastlane supply` (built-in) rather than a third-party plugin**

The `supply` action is built into Fastlane and handles uploading AABs, managing metadata, and promoting to tracks. The existing metadata directory at `fastlane/metadata/android/` already follows the `supply` convention. No additional plugin needed.

**Alternative considered:** `fastlane-plugin-supply_metadata` or third-party uploaders. Rejected because `supply` already meets all requirements and avoids additional dependencies.

**Decision 2: Manual workflow_dispatch trigger for Play Store upload**

A new `workflow_dispatch` trigger in the release workflow lets the developer choose a track (`internal`, `alpha`, `beta`, `production`) and optionally a version tag to upload. This keeps full control over what goes to Play Store and when.

**Alternative considered:** Fully automatic upload on tag push. Rejected because Play Store releases have policy implications (reviews, rollouts) that should not be fully automated without manual oversight.

**Decision 3: Google Play JSON key passed via GitHub Secrets**

The Play Store service account JSON key is stored as `PLAY_STORE_SERVICE_ACCOUNT_KEY` secret. The Fastlane lane reads it from an environment variable and writes it to a temporary file at runtime (never committed).

**Alternative considered:** Encrypting the JSON key in the repo. Rejected because GitHub Secrets is the standard, more secure approach for CI.

**Decision 4: Fastlane uses the same signing config as the existing Gradle build**

The `Fastfile` lane calls `flutter build appbundle --release --flavor gplay` and passes the resulting AAB to `supply`. No Fastlane-specific signing configuration needed — Gradle handles it via `key.properties` and the CI step already writes that file.

**Decision 5: Separate `Gemfile` at project root**

Fastlane's Ruby dependencies are managed via Bundler with a `Gemfile` at the project root. This is the standard Fastlane convention and keeps dependencies versioned and reproducible.

**Alternative considered:** Installing Fastlane via `gem install`. Rejected because it's not reproducible across environments.

**Decision 6: Default build = fdroid, `gplay` flavor is conditional**

The `defaultConfig` in `build.gradle.kts` serves as the fdroid build — no flavor is defined for it. The `gplay` flavor is registered **conditionally** — only when the Gradle task names include `Gplay`:

```kotlin
if (gradle.startParameter.taskNames.any { it.contains("Gplay", ignoreCase = true) }) {
    flavorDimensions += listOf("store")
    productFlavors {
        create("gplay") {
            dimension = "store"
            applicationId = "dev.henriquecouto.calsync_gplay"
        }
    }
}
```

This produces two behaviors:

```
flutter build apk --release
  → taskNames: [assembleRelease]
  → gplay NÃO é registrado
  → assembleRelease usa defaultConfig → app-release.apk (fdroid)

flutter build apk --release --flavor gplay
  → taskNames: [assembleGplayRelease]
  → gplay É registrado
  → assembleGplayRelease → app-gplay-release.apk
```

FDroid APK filenames use standard naming (`app-armeabi-v7a-release.apk`) since fdroid is a non-flavored build. Gplay APK filenames include the flavor suffix (`app-gplay-release.apk`).

**Decision 7: Flavor-independent MethodChannel name (`calsync/calendar`)**

The current channel name `dev.henriquecouto.calsync/calendar` embeds the application ID. With flavors, this would need to differ per flavor. Using `calsync/calendar` decouples the channel from the application ID entirely.

**Alternative considered:** Using a flavor-specific channel or keeping it tied to the fdroid ID. Rejected because it creates unnecessary coupling and potential for mismatch.

**Decision 8: Kotlin package and source directory unchanged**

```
android/app/src/main/kotlin/dev/henriquecouto/calsync/
├── MainActivity.kt
├── BootReceiver.kt
├── CalendarSyncJobService.kt
└── SoftDeletePlugin.kt
```

All Kotlin files stay in `dev.henriquecouto.calsync` package. The `applicationId` in Gradle is independent of the Kotlin source package — Android resolves component classes by their FQN, not by the app ID. This means:

- ProGuard `-keep` rules continue to match (they reference the Kotlin package, not applicationId)
- AndroidManifest `<service>` and `<receiver>` declarations use FQN and remain valid
- `GeneratedPluginRegistrant.java` references to `dev.henriquecouto.calsync.SoftDeletePlugin` stay valid
- `CalendarSyncJobService.schedule()` uses `context.packageName` which dynamically resolves to the current flavor's applicationId at runtime — no code change needed

**Alternative considered:** Moving Kotlin sources to flavor-specific source sets. Rejected because no Kotlin code differs between flavors; only the Gradle `applicationId` needs to change.

## Risks / Trade-offs

- **[Risk] Google Play service account key is a sensitive credential.** → Mitigation: Never committed to the repo. Stored as GitHub Secret (`PLAY_STORE_SERVICE_ACCOUNT_KEY`). Included in `.gitignore` patterns.
- **[Risk] Fastlane Ruby version incompatibility with CI runner.** → Mitigation: Use `ruby/setup-ruby@v1` in CI to pin a compatible Ruby version (3.2+). `Gemfile.lock` ensures reproducible installs.
- **[Risk] Play Store upload fails due to version code conflicts or policy issues.** → Mitigation: The workflow dispatch step is optional and isolated — a failed upload does not block the GitHub Release. The lane can be re-run independently.
- **[Risk] Local development requires Ruby + Bundler installed.** → Mitigation: Document prerequisites in AGENTS.md. Fastlane is only required for release managers, not for regular development.
- **[Risk] Forgetting `--flavor` flag in local release builds.** → Mitigation: Without `--flavor`, Gradle only sees `fdroid` (the `gplay` flavor wasn't registered since no `Gplay` task was requested). Building for gplay always requires the explicit `--flavor gplay` flag. Document flavor usage in AGENTS.md.
- **[Risk] F-Droid users cannot upgrade to Play Store version (and vice versa) due to different application IDs.** → Mitigation: This is intentional and expected. Each store's app is a separate installation. Users must choose a channel and stick with it. This is the standard Android multi-store distribution pattern.

## Migration Plan

1. No migration needed for existing F-Droid users — the `fdroid` flavor keeps `dev.henriquecouto.calsync` unchanged.
2. After setup, the developer:
   a. Creates a Google Play service account and downloads the JSON key
   b. Adds `PLAY_STORE_SERVICE_ACCOUNT_KEY` to GitHub repository secrets
   c. Commits all configuration files
   d. On the next release, the CI builds both flavors; the developer triggers the workflow dispatch to upload the gplay AAB
3. **Rollback for Fastlane:** Remove or comment out the workflow dispatch section in `release.yml`.
4. **Rollback for flavors:** Remove `productFlavors` block from `build.gradle.kts` and revert the `flutter build` commands in CI. The MethodChannel rename is benign and can stay.

## Open Questions

- Which Play Store track should be the default for `workflow_dispatch`? (Recommend: `internal` as safest default)
- Should the Fastlane lane also manage Play Store listing metadata (descriptions, screenshots) beyond just the AAB upload? (Current metadata at `fastlane/metadata/android/` is ready for `supply` to consume)

# Build Flavors

## Purpose

Configure Android product flavors to produce separate artifacts for F-Droid and Google Play distribution channels, each with its own application ID, from a single codebase.

## Requirements

### Requirement: Two product flavors with distinct application IDs
The system SHALL use the base `defaultConfig` (application ID `dev.henriquecouto.calsync`) for the non-flavored `fdroid` build. The system SHALL conditionally register a `gplay` flavor only when Gradle task names contain `Gplay` (i.e., `--flavor gplay` was explicitly passed), overriding the application ID to `dev.henriquecouto.calsync_gplay`.

#### Scenario: Default build produces fdroid APK with standard name
- **WHEN** `flutter build apk --release` is executed
- **THEN** a single APK set is produced with application ID `dev.henriquecouto.calsync` and standard filenames (`app-armeabi-v7a-release.apk`, etc.)

#### Scenario: GPlay flavor uses the Play Store application ID
- **WHEN** the `gplay` flavor is built via `--flavor gplay`
- **THEN** the APK or AAB has application ID `dev.henriquecouto.calsync_gplay` and flavor-specific filenames (`app-gplay-release.apk`)

#### Scenario: Default build without --flavor only builds base variant
- **WHEN** `flutter build apk --release` is executed without `--flavor`
- **THEN** only the base (fdroid) variant is built; no gplay artifacts are produced

#### Scenario: Both variants share the same namespace
- **WHEN** either variant is built (base or gplay flavor)
- **THEN** the Gradle `namespace` remains `dev.henriquecouto.calsync`, ensuring R class generation and manifest resolution are identical

### Requirement: Kotlin source package is unchanged
The system SHALL keep all Kotlin source files under the `dev.henriquecouto.calsync` package in `android/app/src/main/kotlin/dev/henriquecouto/calsync/` without flavor-specific source sets, since no Kotlin code differs between flavors.

#### Scenario: Kotlin classes resolve correctly in both flavors
- **WHEN** either flavor is built
- **THEN** `MainActivity`, `BootReceiver`, `CalendarSyncJobService`, and `SoftDeletePlugin` compile and resolve without errors

#### Scenario: ProGuard rules remain valid for both flavors
- **WHEN** the release build runs for either flavor
- **THEN** all `-keep` rules referencing `dev.henriquecouto.calsync.*` classes apply correctly

### Requirement: AndroidManifest component references work across flavors
The system SHALL ensure that `<service>`, `<receiver>`, and `<activity>` declarations in `AndroidManifest.xml` resolve correctly for both flavors using FQN or namespace-relative class names.

#### Scenario: Service declaration resolves in gplay flavor
- **WHEN** the `gplay` flavor is built
- **THEN** `android:name="dev.henriquecouto.calsync.CalendarSyncJobService"` resolves to the correct JobService class

#### Scenario: Activity declaration resolves via namespace
- **WHEN** either flavor is built
- **THEN** `android:name=".MainActivity"` resolves to `dev.henriquecouto.calsync.MainActivity` using the namespace

### Requirement: MethodChannel uses a flavor-independent name
The system SHALL rename the MethodChannel from `dev.henriquecouto.calsync/calendar` to `calsync/calendar` in both `lib/calendar/calendar_service.dart` and `android/app/src/main/kotlin/dev/henriquecouto/calsync/SoftDeletePlugin.kt` so that the channel name does not depend on the application ID.

#### Scenario: Channel name matches in Dart and Kotlin
- **WHEN** the app runs under either flavor
- **THEN** the MethodChannel `calsync/calendar` connects correctly between Dart and Kotlin

#### Scenario: Channel name is flavor-independent
- **WHEN** switching between `fdroid` and `gplay` flavors
- **THEN** the MethodChannel name `calsync/calendar` does not change

### Requirement: Flutter build commands support flavor selection
The system SHALL support building per-variant artifacts via standard Flutter CLI flags: `flutter build apk --release` (fdroid, no flavor needed), `flutter build apk --release --flavor gplay`, and `flutter build appbundle --release --flavor gplay`.

#### Scenario: F-Droid APK build
- **WHEN** `flutter build apk --release` or `flutter build apk --release --split-per-abi` is executed
- **THEN** the APK is produced with application ID `dev.henriquecouto.calsync` and no flavor suffix in filenames

#### Scenario: GPlay AAB build
- **WHEN** `flutter build appbundle --release --flavor gplay` is executed
- **THEN** the AAB is produced with application ID `dev.henriquecouto.calsync_gplay`

### Requirement: WorkManager callbacks function across flavors
The system SHALL maintain background sync functionality (`CalendarSyncJobService`, `sync_scheduler.dart`, `sync_task.dart`) across both flavors without modification, since task names and callback references are flavor-independent strings.

#### Scenario: Background sync triggers in gplay flavor
- **WHEN** a calendar event changes and `CalendarSyncJobService` is triggered
- **THEN** the WorkManager task `calendar_sync_periodic` executes the `syncTask` callback regardless of flavor

#### Scenario: Boot receiver reschedules in both flavors
- **WHEN** the device boots and `BootReceiver` fires
- **THEN** `CalendarSyncJobService.schedule()` correctly builds a `ComponentName` using `context.packageName` for the current flavor

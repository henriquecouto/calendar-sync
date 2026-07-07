# Pubspec Overlay

## Purpose

Keep `pubspec.yaml` as the single source of truth for shared dependencies. A separate `pubspec_gplay.yaml` file contains only the billing extras (3 lines). A build script merges them in, validates no duplicates, builds, and reverts.

## Requirements

### Requirement: Overlay file contains only billing dependencies

The system SHALL maintain `pubspec_gplay.yaml` as a flat text file containing exactly the gplay-only dependency lines with their indentation. The file SHALL NOT be a complete pubspec — it contains only the dependencies to inject. It SHALL include `in_app_purchase`, `in_app_purchase_android`, `in_app_purchase_platform_interface`, and `url_launcher` with their version constraints.

#### Scenario: Overlay file content

- **WHEN** `pubspec_gplay.yaml` is read by the build script
- **THEN** it contains exactly 4 lines: the billing and url_launcher dependencies with proper YAML indentation

### Requirement: Main pubspec has no billing dependencies

The system SHALL ensure `pubspec.yaml` does NOT declare `in_app_purchase`, `in_app_purchase_android`, or `in_app_purchase_platform_interface` anywhere in its dependencies or dev_dependencies sections.

#### Scenario: Fdroid pub get resolves zero billing packages

- **WHEN** `flutter pub get` is executed without the build script
- **THEN** the resolved dependency tree contains no packages with "in_app_purchase" in their name

### Requirement: Build script merges overlay with duplicate detection

The system SHALL provide `scripts/gplay_build.sh` that: reads each dependency from the overlay, checks it does NOT already exist in `pubspec.yaml` (errors if it does), appends the billing lines to the dependencies block, runs `flutter pub get`, executes the build command, and reverts `pubspec.yaml` on exit (via trap).

#### Scenario: Script merges and builds successfully

- **WHEN** `scripts/gplay_build.sh "flutter build apk --release --flavor gplay --dart-define=SUBSCRIPTIONS_ENABLED=true"` is executed
- **THEN** billing deps are appended to pubspec.yaml, pub get runs, the APK builds, and pubspec.yaml is reverted to original

#### Scenario: Script reverts on build failure

- **WHEN** the Flutter build command inside the script fails (non-zero exit)
- **THEN** pubspec.yaml is reverted to its original content regardless of the failure

#### Scenario: Script errors on duplicate dependency

- **WHEN** `in_app_purchase` is already declared in `pubspec.yaml` AND `pubspec_gplay.yaml` also contains it
- **THEN** the script prints an error message naming the duplicate dependency and exits with non-zero status without modifying pubspec.yaml

#### Scenario: Script works for local dev commands

- **WHEN** `scripts/gplay_build.sh flutter run --flavor gplay --dart-define=SUBSCRIPTIONS_ENABLED=true` is executed
- **THEN** the Flutter run session starts with billing deps resolved, and pubspec.yaml is reverted after the run stops

### Requirement: Build commands use the script

The system SHALL update `AGENTS.md`, CI workflow, and Fastlane to invoke gplay builds through `scripts/gplay_build.sh` instead of calling `flutter build` directly for the gplay flavor.

#### Scenario: CI gplay build uses the script

- **WHEN** the GitHub Actions release workflow builds the gplay flavor
- **THEN** the build step invokes `scripts/gplay_build.sh` with the appropriate Flutter command

#### Scenario: Fastlane uses the script

- **WHEN** `bundle exec fastlane deploy` runs
- **THEN** the Fastlane `sh` call invokes `scripts/gplay_build.sh` before the deploy step

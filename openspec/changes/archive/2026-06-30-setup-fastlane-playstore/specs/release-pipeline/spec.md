# Release Pipeline

## MODIFIED Requirements

### Requirement: Build release APK on push to main
The system SHALL trigger a GitHub Actions workflow on every push to the `main` branch. The workflow SHALL execute `flutter build apk --release --split-per-abi` (fdroid) in a `ubuntu-latest` runner with Flutter SDK installed.

#### Scenario: Push to main triggers fdroid APK build
- **WHEN** a commit is pushed to the `main` branch
- **THEN** the workflow runs APK builds for fdroid and produces release APK artifacts

#### Scenario: Flutter SDK is not pre-installed
- **WHEN** the workflow starts on a fresh `ubuntu-latest` runner
- **THEN** the workflow installs Flutter SDK via `subosito/flutter-action@v2` before building

### Requirement: Create a GitHub Release with fdroid artifacts
The system SHALL create a GitHub Release associated with the generated tag, attach the fdroid APK files as release assets, and include auto-generated release notes.

#### Scenario: Release created with fdroid artifacts
- **WHEN** the workflow completes fdroid builds successfully and creates a tag
- **THEN** a GitHub Release is created with the fdroid APK files and auto-generated release notes attached

#### Scenario: Release notes summarize changes since last tag
- **WHEN** the GitHub Release is created
- **THEN** the release notes contain the list of merged PRs and commits since the previous release tag

### Requirement: Play Store upload on every release
The system SHALL upload the gplay AAB to the Google Play Store via Fastlane as part of every workflow run (both push to `main` and `workflow_dispatch`). On push to `main`, the upload SHALL default to the `internal` track. On `workflow_dispatch`, the upload SHALL use the user-selected track.

#### Scenario: Push to main uploads to internal track
- **WHEN** a commit is pushed to `main` and the release proceeds
- **THEN** the gplay AAB is built and uploaded to the Play Store `internal` testing track

#### Scenario: Workflow dispatch uploads to selected track
- **WHEN** a developer triggers `workflow_dispatch` with a specific track
- **THEN** the gplay AAB is built and uploaded to the selected Play Store track

#### Scenario: Play Store upload failure does not affect GitHub Release
- **WHEN** the Play Store upload step fails
- **THEN** the GitHub Release and fdroid artifacts remain unaffected

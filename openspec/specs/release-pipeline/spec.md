# Release Pipeline

## Purpose

Automatically build release artifacts (APK and App Bundle) and publish a GitHub Release when changes are pushed to the `main` branch.

## Requirements

### Requirement: Build release APK on push to main
The system SHALL trigger a GitHub Actions workflow on every push to the `main` branch. The workflow SHALL execute `flutter build apk --release --split-per-abi` (fdroid) in a `ubuntu-latest` runner with Flutter SDK installed.

#### Scenario: Push to main triggers fdroid APK build
- **WHEN** a commit is pushed to the `main` branch
- **THEN** the workflow runs APK builds for fdroid and produces release APK artifacts

#### Scenario: Flutter SDK is not pre-installed
- **WHEN** the workflow starts on a fresh `ubuntu-latest` runner
- **THEN** the workflow installs Flutter SDK via `subosito/flutter-action@v2` before building

### Requirement: Build release App Bundle on push to main
The system SHALL execute `flutter build appbundle --release --flavor gplay` as part of the same workflow triggered on push to `main`, producing a gplay AAB artifact.

#### Scenario: Push to main triggers App Bundle build
- **WHEN** a commit is pushed to the `main` branch
- **THEN** the workflow runs `flutter build appbundle --release --flavor gplay` and produces a gplay AAB artifact

### Requirement: Automatically tag the release commit
The system SHALL extract the version and build number from `pubspec.yaml` and create a Git tag in the format `v<version>+<build-number>` (e.g., `v1.0.0+1`). The tag check SHALL run before any build step (fail-fast). If the tag already exists and points to a different commit, the workflow SHALL fail. If the tag already exists and points to the same commit (i.e., a re-run), the workflow SHALL skip the release and exit successfully.

#### Scenario: Tag created from pubspec version
- **WHEN** `pubspec.yaml` contains `version: 1.2.3+4`, the commit is pushed to main, and no tag `v1.2.3+4` exists
- **THEN** a Git tag `v1.2.3+4` is created pointing to that commit and the release proceeds

#### Scenario: Tag exists on a different commit
- **WHEN** a tag `v1.0.0+1` already exists pointing to a different commit and a push to main arrives with the same version in `pubspec.yaml`
- **THEN** the workflow fails with an error indicating the tag already exists and the version must be bumped

#### Scenario: Tag exists on the same commit (re-run)
- **WHEN** a tag `v1.0.0+1` already exists pointing to the current commit (e.g., a previous workflow run already created it)
- **THEN** the workflow skips the release step and exits successfully

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

### Requirement: Generate F-Droid changelog during release
The system SHALL generate a plain-text changelog file from the git commit history between the previous tag and the current HEAD. The file SHALL be written to `fastlane/metadata/android/en-US/changelogs/<versionCode>.txt` where `<versionCode>` is the Android version code extracted from `pubspec.yaml` (the number after `+` in the version string). The workflow SHALL commit and push the changelog file before creating the release tag.

#### Scenario: Changelog generated from git history
- **WHEN** the release workflow runs and commits exist since the last tag
- **THEN** a changelog file is created with one bullet (`- `) per commit message, written to `fastlane/metadata/android/en-US/changelogs/<versionCode>.txt`

#### Scenario: First release with no previous tag
- **WHEN** no previous Git tag exists in the repository
- **THEN** the changelog includes all commits in the repository history

#### Scenario: Changelog committed before tag
- **WHEN** the changelog file is generated
- **THEN** it is committed and pushed to the repository before the release tag is created, so the tag points to the commit containing the changelog

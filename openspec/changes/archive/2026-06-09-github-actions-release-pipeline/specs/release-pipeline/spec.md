# Release Pipeline

## Purpose

Automatically build release artifacts (APK and App Bundle) and publish a GitHub Release when changes are pushed to the `main` branch.

## ADDED Requirements

### Requirement: Build release APK on push to main
The system SHALL trigger a GitHub Actions workflow on every push to the `main` branch. The workflow SHALL execute `flutter build apk --release` in a `ubuntu-latest` runner with Flutter SDK installed.

#### Scenario: Push to main triggers APK build
- **WHEN** a commit is pushed to the `main` branch
- **THEN** the workflow runs `flutter build apk --release` and produces a release APK artifact

#### Scenario: Flutter SDK is not pre-installed
- **WHEN** the workflow starts on a fresh `ubuntu-latest` runner
- **THEN** the workflow installs Flutter SDK via `subosito/flutter-action@v2` before building

### Requirement: Build release App Bundle on push to main
The system SHALL execute `flutter build appbundle --release` as part of the same workflow triggered on push to `main`, producing a release AAB artifact.

#### Scenario: Push to main triggers App Bundle build
- **WHEN** a commit is pushed to the `main` branch
- **THEN** the workflow runs `flutter build appbundle --release` and produces a release AAB artifact

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

### Requirement: Create a GitHub Release with artifacts
The system SHALL create a GitHub Release associated with the generated tag, attach both the APK and AAB files as release assets, and include auto-generated release notes.

#### Scenario: Release created with both artifacts
- **WHEN** the workflow completes both builds successfully and creates a tag
- **THEN** a GitHub Release is created with the APK file, the AAB file, and auto-generated release notes attached

#### Scenario: Release notes summarize changes since last tag
- **WHEN** the GitHub Release is created
- **THEN** the release notes contain the list of merged PRs and commits since the previous release tag

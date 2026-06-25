# Fastlane Play Store Upload

## Purpose

Configure Fastlane to automate building the release App Bundle and uploading it to the Google Play Store, supporting all standard release tracks.

## Requirements

### Requirement: Fastlane is configured with project credentials
The system SHALL have a `fastlane/Appfile` that declares the package name `dev.henriquecouto.calsync_gplay` (the Play Store application ID from the `gplay` flavor) and the path to the Google Play service account JSON key (read from an environment variable or a local file). The system SHALL have a `fastlane/Fastfile` that imports the app identifier from the `Appfile`.

#### Scenario: Appfile provides package name
- **WHEN** Fastlane is invoked with any lane
- **THEN** the package name `dev.henriquecouto.calsync_gplay` is available to all actions

#### Scenario: Service account key is provided via environment variable
- **WHEN** the environment variable `PLAY_STORE_SERVICE_ACCOUNT_KEY` is set to a valid JSON key path
- **THEN** Fastlane `supply` uses that key to authenticate with Google Play

### Requirement: Fastlane can build and upload to any Play Store track
The system SHALL provide a Fastlane lane named `deploy` that accepts a `track` parameter and executes `flutter build appbundle --release --flavor gplay` followed by `supply` to upload the AAB to the specified Play Store track. The lane SHALL accept track values: `internal`, `alpha`, `beta`, and `production`.

#### Scenario: Deploy to internal track
- **WHEN** the `deploy` lane is invoked with `track: "internal"`
- **THEN** the release AAB is built and uploaded to the internal testing track

#### Scenario: Deploy to production track
- **WHEN** the `deploy` lane is invoked with `track: "production"`
- **THEN** the release AAB is built and uploaded to the production track

#### Scenario: Deploy fails on build error
- **WHEN** `flutter build appbundle --release` fails
- **THEN** the lane stops with an error and does not attempt to upload

### Requirement: Fastlane uploads Play Store metadata
The system SHALL configure `supply` to use the metadata directory at `fastlane/metadata/android/` so that all localized descriptions, changelogs, and screenshots are uploaded alongside the AAB.

#### Scenario: Metadata is uploaded with the AAB
- **WHEN** the `deploy` lane is invoked
- **THEN** `supply` reads metadata from `fastlane/metadata/android/` and uploads it to the Play Store listing

### Requirement: Fastlane dependencies are managed via Bundler
The system SHALL have a `Gemfile` at the project root declaring `fastlane` as a dependency with a locked version. The system SHALL have a committed `Gemfile.lock` to ensure reproducible installations.

#### Scenario: Fastlane is installed via Bundler
- **WHEN** `bundle install` is executed
- **THEN** Fastlane and its dependencies are installed at the versions specified in `Gemfile.lock`

#### Scenario: Fastlane is invoked via Bundler
- **WHEN** `bundle exec fastlane <lane>` is executed
- **THEN** Fastlane runs using the Bundler-managed version, not any system-installed version

### Requirement: Sensitive files are excluded from version control
The system SHALL add Fastlane-related temporary files and Play Store credential files to `.gitignore`.

#### Scenario: Play Store credentials are not committed
- **WHEN** a developer places a Google Play JSON key anywhere in the project
- **THEN** Git does not track the file due to `.gitignore` rules for `*.json` keys in Fastlane directories

#### Scenario: Fastlane temporary files are ignored
- **WHEN** Fastlane generates reports, temporary metadata, or build output in `fastlane/`
- **THEN** those files are excluded from Git tracking

### Requirement: CI workflow uploads to Play Store on every release
The system SHALL extend the existing GitHub Actions release workflow (`release.yml`) so that the Play Store upload job runs on both `push` to `main` and `workflow_dispatch` triggers. On push, the upload SHALL default to the `internal` track. On dispatch, the workflow SHALL accept a `track` input and use the selected track. The job SHALL install Ruby and Bundler, run `bundle install`, and execute `bundle exec fastlane deploy track:<track>`.

#### Scenario: Push to main triggers internal track upload
- **WHEN** a commit is pushed to `main`
- **THEN** the workflow builds the gplay AAB and uploads to the `internal` Play Store track

#### Scenario: Manual dispatch uploads to selected track
- **WHEN** a developer triggers the `workflow_dispatch` event with a track selected
- **THEN** the workflow builds the gplay AAB and uploads to the specified track

#### Scenario: Upload uses Play Store credentials from GitHub Secrets
- **WHEN** the Play Store upload step runs in CI
- **THEN** the `PLAY_STORE_SERVICE_ACCOUNT_KEY` secret is loaded and passed to Fastlane

# F-Droid Metadata

## Purpose

Provide structured store listing metadata following the Fastlane layout so that F-Droid (and optionally Google Play) can consume app title, descriptions, changelogs, and graphics.

## ADDED Requirements

### Requirement: App title metadata file
The system SHALL provide a `title.txt` file at `fastlane/metadata/android/en-US/title.txt` containing the application name, limited to 30 characters.

#### Scenario: Title file is present
- **WHEN** the repository is checked out
- **THEN** `fastlane/metadata/android/en-US/title.txt` exists and contains "Calendar Sync"

### Requirement: Short description metadata file
The system SHALL provide a `short_description.txt` file at `fastlane/metadata/android/en-US/short_description.txt` summarizing the app in 80 characters or fewer.

#### Scenario: Short description file is present
- **WHEN** the repository is checked out
- **THEN** `fastlane/metadata/android/en-US/short_description.txt` exists and contains a one-line summary of the app

### Requirement: Full description metadata file
The system SHALL provide a `full_description.txt` file at `fastlane/metadata/android/en-US/full_description.txt` describing the app's functionality in detail (minimum 4 sentences).

#### Scenario: Full description file is present
- **WHEN** the repository is checked out
- **THEN** `fastlane/metadata/android/en-US/full_description.txt` exists and contains at least 4 sentences describing what the app does, how it works, and any setup requirements

### Requirement: Changelog directory
The system SHALL provide a `changelogs/` directory at `fastlane/metadata/android/en-US/changelogs/` for per-version changelog files named by version code (e.g., `1.txt`).

#### Scenario: Changelog directory exists
- **WHEN** the repository is checked out
- **THEN** `fastlane/metadata/android/en-US/changelogs/` exists and is ready to accept per-version `.txt` files

#### Scenario: No changelog for current version
- **WHEN** a version code has no corresponding changelog file
- **THEN** the absence is acceptable (F-Droid falls back to no changelog for that version)

### Requirement: Graphics image directory
The system SHALL provide an `images/` directory at `fastlane/metadata/android/en-US/images/` structured for store listing graphics including `icon.png`, `featureGraphic.png`, and phone screenshots.

#### Scenario: Image directory scaffold exists
- **WHEN** the repository is checked out
- **THEN** `fastlane/metadata/android/en-US/images/` exists as a placeholder, ready for graphics to be added

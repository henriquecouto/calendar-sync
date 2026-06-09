## ADDED Requirements

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

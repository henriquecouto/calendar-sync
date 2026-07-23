## MODIFIED Requirements

### Requirement: App title metadata file
The system SHALL provide a `title.txt` file at `fastlane/metadata/android/en-US/title.txt` containing the application name and a keyword-dense subtitle, limited to 30 characters.

#### Scenario: Title file is present
- **WHEN** the repository is checked out
- **THEN** `fastlane/metadata/android/en-US/title.txt` exists and contains "CalSync - Local Calendar Sync"

### Requirement: Short description metadata file
The system SHALL provide a `short_description.txt` file at `fastlane/metadata/android/en-US/short_description.txt` summarizing the app's unique selling points in 80 characters or fewer.

#### Scenario: Short description file is present
- **WHEN** the repository is checked out
- **THEN** `fastlane/metadata/android/en-US/short_description.txt` exists and contains "Sync & merge local calendars offline. Free, open source, no account needed."

### Requirement: Full description metadata file
The system SHALL provide a `full_description.txt` file at `fastlane/metadata/android/en-US/full_description.txt` describing the app's functionality, competitive positioning, use cases, and unique selling points. The file SHALL be at least 4 sentences and SHALL name key SaaS competitors (OneCal, CalendarBridge, Reclaim.ai) to position CalSync as a free, open source alternative.

#### Scenario: Full description file is present
- **WHEN** the repository is checked out
- **THEN** `fastlane/metadata/android/en-US/full_description.txt` exists and contains at least 4 sentences describing the app's capabilities, competitive differentiation, and use cases

#### Scenario: Full description competitor positioning
- **WHEN** the full description is read
- **THEN** the first sentence identifies CalSync as a free open source alternative to OneCal, CalendarBridge, and Reclaim.ai

#### Scenario: Full description emphases offline privacy
- **WHEN** the full description is read
- **THEN** it explicitly states the app works offline, requires no internet connection, and keeps all calendar data on-device

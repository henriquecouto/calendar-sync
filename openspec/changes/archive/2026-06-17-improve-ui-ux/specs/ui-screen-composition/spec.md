## ADDED Requirements

### Requirement: Dashboard as home screen
The app SHALL display a Dashboard as its home screen, showing sync profile status, quick actions, and recent activity at a glance.

#### Scenario: Dashboard shows configured profile
- **WHEN** the user opens the app with a sync profile configured and permissions granted
- **THEN** the Dashboard SHALL display a profile card showing source calendar, target calendar, event name, sync interval, and whether sync is enabled
- **AND** the profile card SHALL show the time of the last sync

#### Scenario: Dashboard shows no profiles state
- **WHEN** the user opens the app with no sync profile configured
- **THEN** the Dashboard SHALL display an empty state with a message and a "Create Profile" action

#### Scenario: Dashboard shows quick actions
- **WHEN** the Dashboard is displayed
- **THEN** a "Sync All" button and a "Dry Run" button SHALL be visible in a Quick Actions section

#### Scenario: Quick actions disabled when no profile exists
- **WHEN** no sync profile is configured
- **THEN** the "Sync All" and "Dry Run" buttons SHALL be disabled

#### Scenario: Dashboard shows recent activity
- **WHEN** the Dashboard is displayed and sync history exists
- **THEN** the most recent sync runs SHALL be shown in a Recent Activity section
- **AND** a "View full history" link SHALL navigate to the Sync History screen

### Requirement: Profile list layout for future multi-profile support
The Dashboard SHALL use a list-based layout for profile cards, even when only one profile exists.

#### Scenario: Single profile renders as a one-item list
- **WHEN** exactly one sync profile is configured
- **THEN** a single profile card SHALL be displayed in a scrollable list area
- **AND** adding a second profile in the future SHALL not require layout changes

### Requirement: Profile configuration as a separate screen
Sync profile configuration SHALL be on its own screen (`ProfileConfigScreen`), navigated to from the Dashboard.

#### Scenario: Navigate to profile config from Dashboard
- **WHEN** the user taps the profile card or a "Configure" link on the Dashboard
- **THEN** the app SHALL push the `ProfileConfigScreen` with that profile's current settings pre-filled

#### Scenario: Profile config screen structure
- **WHEN** the `ProfileConfigScreen` is displayed
- **THEN** it SHALL contain sections for calendar pairing (source and target dropdowns), event naming (text field), schedule (interval dropdown and sync enabled toggle), and a delete action
- **AND** changes SHALL be persisted via `SettingsService` on save

#### Scenario: Create new profile
- **WHEN** the user taps "Create Profile" from the empty Dashboard state
- **THEN** the app SHALL push the `ProfileConfigScreen` in creation mode with empty/default values

### Requirement: Extracted shared widgets
Reusable widgets for displaying sync results SHALL be extracted into `lib/widgets/` and reused across screens.

#### Scenario: SyncPlanCard widget reused
- **WHEN** the dry-run screen displays sync plan entries (create, update, delete, skip, error)
- **THEN** each entry SHALL use the shared `SyncPlanCard` widget
- **AND** the widget SHALL accept an entry type and render the appropriate icon, color, and label using `colorScheme` semantic roles

#### Scenario: EmptyState widget reused
- **WHEN** any screen has no data to display (no profiles, no sync history, no dry-run results, no calendars)
- **THEN** an `EmptyState` widget SHALL be displayed with a descriptive icon, title, and optional subtitle or action
- **AND** the same `EmptyState` widget SHALL be reusable across all screens

#### Scenario: ProfileCard widget
- **WHEN** the Dashboard renders a sync profile
- **THEN** it SHALL use the shared `ProfileCard` widget
- **AND** the widget SHALL display source calendar name, target calendar name, event name, interval, enabled status, and last sync time
- **AND** the widget SHALL accept callbacks for sync and configure actions

### Requirement: Empty state UI for all screens
Every screen that can be empty SHALL display a meaningful empty-state placeholder.

#### Scenario: No sync history
- **WHEN** the user opens the sync status screen and no sync runs have been recorded
- **THEN** an empty state SHALL display a "No sync history yet" message with a relevant icon

#### Scenario: No events to sync in dry run
- **WHEN** the user runs a dry run and no source calendar events are found
- **THEN** an empty state SHALL display a "No events to sync" message

#### Scenario: No calendars available
- **WHEN** the ProfileConfigScreen loads and no calendars are found on the device
- **THEN** the dropdown menus SHALL display an empty state indicating no calendars are available

### Requirement: Consistent app bar styling
All screens SHALL have a consistent app bar with the dynamic color scheme applied.

#### Scenario: App bars match theme
- **WHEN** any screen with an app bar is displayed (Dashboard, ProfileConfig, SyncHistory, DryRun)
- **THEN** the app bar SHALL use the dynamic color scheme for background, text, and icons

### Requirement: Loading state for calendar dropdowns
The calendar dropdowns on the ProfileConfigScreen SHALL show a loading indicator while the calendar list is being fetched.

#### Scenario: Calendars loading
- **WHEN** calendar data is being fetched on the ProfileConfigScreen
- **THEN** the dropdown menus SHALL display a loading state
- **AND** SHALL become interactive once the calendar list is available

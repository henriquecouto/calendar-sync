## ADDED Requirements

### Requirement: Dynamic color from system wallpaper
The app SHALL derive its color scheme from the Android system wallpaper on devices running Android 12+, and SHALL fall back to a default seed color on older platforms.

#### Scenario: Android 12+ device extracts wallpaper colors
- **WHEN** the app launches on an Android 12+ device
- **THEN** the app's color scheme SHALL be derived from the system wallpaper
- **AND** the color scheme SHALL adapt automatically when the user changes their wallpaper

#### Scenario: Pre-Android-12 device uses fallback seed
- **WHEN** the app launches on Android 11 or older, or a non-Android platform
- **THEN** the app SHALL use a color scheme generated from a default fallback seed color

### Requirement: Light and dark theme support
The app SHALL provide both a light theme and a dark theme, automatically following the device's system brightness setting.

#### Scenario: System set to light mode
- **WHEN** the device is set to light mode
- **THEN** the app SHALL render using the light variant of the dynamic color scheme

#### Scenario: System set to dark mode
- **WHEN** the device is set to dark mode
- **THEN** the app SHALL render using the dark variant of the dynamic color scheme

#### Scenario: Theme switches while app is running
- **WHEN** the user changes the system brightness setting while the app is running
- **THEN** the app SHALL immediately switch to the corresponding theme without requiring a restart

### Requirement: Consistent theming across all screens
Every screen and widget in the app SHALL derive its colors from `Theme.of(context).colorScheme`, with no hardcoded color constants.

#### Scenario: All screens use dynamic colors
- **WHEN** any screen is displayed (home, permission gate, dry run, sync status)
- **THEN** all background, text, and accent colors SHALL match the dynamic color scheme
- **AND** no widget SHALL use hardcoded `Colors.*` constants for its primary appearance

#### Scenario: Permission gate inherits theme
- **WHEN** the permission gate screen is shown (granting or denied state)
- **THEN** it SHALL use the same dynamic color scheme as the main app
- **AND** buttons and text SHALL match the Material You palette

### Requirement: Semantic color usage for status indicators
Status indicators (success, error, warning, neutral) SHALL use semantic `colorScheme` roles rather than hardcoded colors.

#### Scenario: Sync results use semantic colors
- **WHEN** sync results are displayed (created, updated, deleted, errored, skipped)
- **THEN** success states SHALL use `colorScheme.primary`
- **AND** error states SHALL use `colorScheme.error`
- **AND** warning states SHALL use `colorScheme.tertiary`
- **AND** neutral states SHALL use `colorScheme.outline`

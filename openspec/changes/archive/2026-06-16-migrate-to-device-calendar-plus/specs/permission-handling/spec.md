## MODIFIED Requirements

### Requirement: Request calendar permissions at runtime
The system SHALL request calendar permissions via `DeviceCalendar.instance.requestPermissions()`, which returns a `CalendarPermissionStatus` enum (granted, denied, restricted, notDetermined). The system SHALL also request `POST_NOTIFICATIONS` via `permission_handler` separately.

#### Scenario: Permissions not yet granted
- **WHEN** the app launches and calendar or notification permissions have never been requested
- **THEN** the app prompts the user to grant all required permissions

#### Scenario: User grants permissions
- **WHEN** the user accepts the permission dialog for both calendar and notifications
- **THEN** the app proceeds to calendar access and notifications will appear after background sync

#### Scenario: User denies permissions
- **WHEN** the user denies any permission dialog
- **THEN** the app shows an explanation of why permissions are needed and offers the option to request again

### Requirement: Gate calendar operations behind permission check
The system SHALL verify that calendar permissions are granted via `DeviceCalendar.instance.hasPermissions()` before calling any `device_calendar_plus` plugin method. Notification permission is NOT required for calendar operations — sync proceeds without it, just without notifications.

#### Scenario: Permissions granted, operation proceeds
- **WHEN** `hasPermissions()` returns `CalendarPermissionStatus.granted` and a sync is triggered
- **THEN** the calendar operation executes normally

#### Scenario: Permissions denied, operation blocked
- **WHEN** calendar permissions are denied and a sync is triggered
- **THEN** the calendar operation is blocked and the user is prompted to grant permissions

#### Scenario: Notification permission denied, sync proceeds
- **WHEN** calendar permissions are granted but notification permission is denied
- **THEN** sync executes normally but no notification is shown on completion

### Requirement: Handle permanently denied permissions
The system SHALL detect when permissions are permanently denied (user selected "Don't ask again") and direct the user to the system Settings app to grant them manually via `openAppSettings()` from `permission_handler`.

#### Scenario: Permissions permanently denied
- **WHEN** the user has permanently denied calendar permissions
- **THEN** the app shows a message explaining how to enable permissions in system Settings and provides a button to open the app's settings page

## MODIFIED Requirements

### Requirement: Request calendar permissions at runtime
The system SHALL request `READ_CALENDAR`, `WRITE_CALENDAR`, and `POST_NOTIFICATIONS` permissions from the user at runtime before any calendar operation.

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
The system SHALL verify that `READ_CALENDAR` and `WRITE_CALENDAR` are granted before calling any `device_calendar` plugin method. Notification permission is NOT required for calendar operations — sync proceeds without it, just without notifications.

#### Scenario: Permissions granted, operation proceeds
- **WHEN** both calendar permissions are granted and a sync is triggered
- **THEN** the calendar operation executes normally

#### Scenario: Permissions denied, operation blocked
- **WHEN** calendar permissions are denied and a sync is triggered
- **THEN** the calendar operation is blocked and the user is prompted to grant permissions

#### Scenario: Notification permission denied, sync proceeds
- **WHEN** calendar permissions are granted but notification permission is denied
- **THEN** sync executes normally but no notification is shown on completion

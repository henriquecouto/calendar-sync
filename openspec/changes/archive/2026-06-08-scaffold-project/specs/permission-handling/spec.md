## ADDED Requirements

### Requirement: Request calendar permissions at runtime
The system SHALL request `READ_CALENDAR` and `WRITE_CALENDAR` permissions from the user at runtime before any calendar operation.

#### Scenario: Permissions not yet granted
- **WHEN** the app launches and calendar permissions have never been requested
- **THEN** the app prompts the user to grant `READ_CALENDAR` and `WRITE_CALENDAR` permissions

#### Scenario: User grants permissions
- **WHEN** the user accepts the permission dialog
- **THEN** the app proceeds to calendar access and the permission status is recorded as granted

#### Scenario: User denies permissions
- **WHEN** the user denies the permission dialog
- **THEN** the app shows an explanation of why permissions are needed and offers the option to request again

### Requirement: Gate calendar operations behind permission check
The system SHALL verify that `READ_CALENDAR` and `WRITE_CALENDAR` are granted before calling any `device_calendar` plugin method.

#### Scenario: Permissions granted, operation proceeds
- **WHEN** both calendar permissions are granted and a sync is triggered
- **THEN** the calendar operation executes normally

#### Scenario: Permissions denied, operation blocked
- **WHEN** calendar permissions are denied and a sync is triggered
- **THEN** the calendar operation is blocked and the user is prompted to grant permissions

### Requirement: Handle permanently denied permissions
The system SHALL detect when permissions are permanently denied (user selected "Don't ask again") and direct the user to the system Settings app to grant them manually.

#### Scenario: Permissions permanently denied
- **WHEN** the user has permanently denied calendar permissions
- **THEN** the app shows a message explaining how to enable permissions in system Settings and provides a button to open the app's settings page

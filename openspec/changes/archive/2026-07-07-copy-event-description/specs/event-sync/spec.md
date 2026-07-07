## MODIFIED Requirements

### Requirement: Create synced event with user-provided name
The system SHALL create a target event using the profile's configured sync event name as the title. When the profile's sync event name is empty, the system SHALL use the source event's original title as the target event's title instead. The target event SHALL copy the source event's start time and end time. The target event's description SHALL be set to the original source event title followed by a sync marker in the format:

```
<original title>
---
🔃 Automatically created by CalSync
```

When the profile's `copyDescription` field is `true` and the source event has a non-null, non-empty description, the source event's description SHALL be prepended before the original title, separated by a blank line:

```
<source description>

<original title>
---
🔃 Automatically created by CalSync
```

When the profile's `copyLocation` field is `true` and the source event has a non-null location, the target event SHALL be created with the source event's location. When `copyLocation` is `false` or the source location is null, the target event SHALL have no location.

If the source event is recurring (`isRecurring == true`), the target event SHALL also be created as recurring, copying the source event's `recurrenceRule`.

#### Scenario: Synced event uses custom name and embeds sync marker
- **WHEN** the user has configured "Busy" as the sync name and a source event titled "Doctor Appointment" appears
- **THEN** the target event has the title "Busy", the same start/end times as the source event
- **AND** the description is:
  ```
  Doctor Appointment
  ---
  🔃 Automatically created by CalSync
  ```

#### Scenario: Synced event uses original title when event name is empty
- **WHEN** the profile has an empty event name and a source event titled "Doctor Appointment" appears
- **THEN** the target event has the title "Doctor Appointment", the same start/end times as the source event
- **AND** the description is:
  ```
  Doctor Appointment
  ---
  🔃 Automatically created by CalSync
  ```

#### Scenario: Copy description disabled uses standard format
- **WHEN** the profile has `copyDescription: false`
- **AND** the source event has description "Q3 planning notes"
- **THEN** the target event description SHALL NOT include "Q3 planning notes"
- **AND** the description SHALL be the standard format (original title + marker)

#### Scenario: Copy description enabled prepends source description
- **WHEN** the profile has `copyDescription: true`
- **AND** the source event has title "Doctor Appointment" and description "Remember to bring documents"
- **THEN** the target event description SHALL be:
  ```
  Remember to bring documents

  Doctor Appointment
  ---
  🔃 Automatically created by CalSync
  ```

#### Scenario: Copy description enabled with null source description
- **WHEN** the profile has `copyDescription: true`
- **AND** the source event has `description: null`
- **THEN** the target event description SHALL be the standard format (no empty block prepended)

#### Scenario: Copy description enabled with empty source description
- **WHEN** the profile has `copyDescription: true`
- **AND** the source event has `description: ""`
- **THEN** the target event description SHALL be the standard format (no empty block prepended)

#### Scenario: Copy location enabled with non-null location
- **WHEN** the profile has `copyLocation: true`
- **AND** the source event has location "Conference Room A"
- **THEN** the target event SHALL be created with `location: "Conference Room A"`

#### Scenario: Copy location disabled with non-null location
- **WHEN** the profile has `copyLocation: false`
- **AND** the source event has location "Conference Room A"
- **THEN** the target event SHALL be created with `location: null` (or absent)

#### Scenario: Copy location enabled with null location
- **WHEN** the profile has `copyLocation: true`
- **AND** the source event has `location: null`
- **THEN** the target event SHALL be created with `location: null` (or absent)

#### Scenario: Both copy options enabled
- **WHEN** the profile has `copyDescription: true` and `copyLocation: true`
- **AND** the source event has description "Q3 notes" and location "Room B"
- **THEN** the target event description SHALL include "Q3 notes" prepended
- **AND** the target event location SHALL be "Room B"

#### Scenario: Recurring source creates recurring target
- **WHEN** the source event has `isRecurring: true`, `eventId: "100"`, `instanceId: "100"`, and `recurrenceRule: "FREQ=WEEKLY;BYDAY=MO"`
- **THEN** the target event is created with the same recurrence rule
- **AND** the description includes the sync marker

#### Scenario: Non-recurring source creates non-recurring target
- **WHEN** the source event has `isRecurring: false`
- **THEN** the target event is created without recurrence fields
- **AND** the description includes the sync marker

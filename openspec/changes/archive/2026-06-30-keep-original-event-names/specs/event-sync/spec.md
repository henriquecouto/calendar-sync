## MODIFIED Requirements

### Requirement: Create synced event with user-provided name
The system SHALL create a target event using the profile's configured sync event name as the title. When the profile's sync event name is empty, the system SHALL use the source event's original title as the target event's title instead. The target event SHALL copy the source event's start time and end time. The target event's description SHALL be set to the original source event title followed by a sync marker in the format:

```
<original title>
---
🔃 Automatically created by CalSync
```

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

#### Scenario: Recurring source creates recurring target
- **WHEN** the source event has `isRecurring: true`, `eventId: "100"`, `instanceId: "100"`, and `recurrenceRule: "FREQ=WEEKLY;BYDAY=MO"`
- **THEN** the target event is created with the same recurrence rule
- **AND** the description includes the sync marker

#### Scenario: Non-recurring source creates non-recurring target
- **WHEN** the source event has `isRecurring: false`
- **THEN** the target event is created without recurrence fields
- **AND** the description includes the sync marker

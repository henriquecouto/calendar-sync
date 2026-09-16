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

When the profile's `omitSourceTitle` field is `true`, the source event's title SHALL NOT appear anywhere in the target event's description as plaintext. Instead, the title line SHALL be replaced by the **full lowercase hex SHA256 fingerprint** of the source event's title (64 hex characters). The target event's description SHALL be:

```
<sha256(title)>
---
🔃 Automatically created by CalSync
```

or, when `copyDescription` is enabled and the source description is non-null and non-empty:

```
<source description>

<sha256(title)>
---
🔃 Automatically created by CalSync
```

The SHA256 fingerprint is deterministic (same title → same hash) but one-way (cannot be reversed to recover the title). It exists purely as a change-detection signal for the sync engine.

The target event's TITLE SHALL still be derived from the profile's `syncEventName` exactly as before — `omitSourceTitle` affects only the description, never the title. If the source event is recurring (`isRecurring == true`), the target event SHALL also be created as recurring, copying the source event's `recurrenceRule`.

#### Scenario: Synced event uses custom name and embeds sync marker

- **WHEN** the user has configured "Busy" as the sync name and a source event titled "Doctor Appointment" appears
- **AND** the profile has `omitSourceTitle: false` (default)
- **THEN** the target event has the title "Busy", the same start/end times as the source event
- **AND** the description is:
  ```
  Doctor Appointment
  ---
  🔃 Automatically created by CalSync
  ```

#### Scenario: Synced event uses original title when event name is empty

- **WHEN** the profile has an empty event name and a source event titled "Doctor Appointment" appears
- **AND** the profile has `omitSourceTitle: false` (default)
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

#### Scenario: Omit source title enabled with custom event name

- **WHEN** the profile has `syncEventName: "Busy"` and `omitSourceTitle: true`
- **AND** the source event has title "Doctor Appointment"
- **THEN** the target event title SHALL be "Busy"
- **AND** the target event description SHALL be:
  ```
  e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
  ---
  🔃 Automatically created by CalSync
  ```
- **AND** "Doctor Appointment" SHALL NOT appear in the target event description
- **AND** the SHA256 fingerprint of "Doctor Appointment" SHALL appear as the first line

#### Scenario: Omit source title enabled with empty event name

- **WHEN** the profile has empty `syncEventName` and `omitSourceTitle: true`
- **AND** the source event has title "Doctor Appointment"
- **THEN** the target event title SHALL be "Doctor Appointment" (title field is NOT affected by omitSourceTitle)
- **AND** the target event description SHALL be:
  ```
  e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
  ---
  🔃 Automatically created by CalSync
  ```

#### Scenario: Omit source title combined with copy description enabled

- **WHEN** the profile has `omitSourceTitle: true` and `copyDescription: true`
- **AND** the source event has title "Doctor Appointment" and description "Bring documents"
- **THEN** the target event title SHALL be the configured sync event name
- **AND** the target event description SHALL be:
  ```
  Bring documents

  e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
  ---
  🔃 Automatically created by CalSync
  ```
- **AND** "Doctor Appointment" SHALL NOT appear in the description

#### Scenario: Omit source title combined with copy description disabled

- **WHEN** the profile has `omitSourceTitle: true` and `copyDescription: false`
- **AND** the source event has title "Doctor Appointment" and description "Bring documents"
- **THEN** the target event description SHALL be:
  ```
  e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
  ---
  🔃 Automatically created by CalSync
  ```
- **AND** neither "Doctor Appointment" nor "Bring documents" SHALL appear in the description

#### Scenario: Omit source title combined with copy description enabled and null source description

- **WHEN** the profile has `omitSourceTitle: true` and `copyDescription: true`
- **AND** the source event has `description: null`
- **THEN** the target event description SHALL be:
  ```
  e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
  ---
  🔃 Automatically created by CalSync
  ```
- **AND** no blank line SHALL precede the SHA256 line

#### Scenario: SHA256 fingerprint differs for different source titles

- **WHEN** the profile has `omitSourceTitle: true`
- **AND** source event A has title "Doctor Appointment"
- **AND** source event B has title "Doctor Visit"
- **THEN** the target events for A and B SHALL have different SHA256 fingerprints as their first lines
- **AND** neither fingerprint SHALL reveal the original title

#### Scenario: SHA256 fingerprint is deterministic across sync cycles

- **WHEN** the profile has `omitSourceTitle: true`
- **AND** a source event with title "Doctor Appointment" is synced in two separate cycles
- **THEN** both target descriptions SHALL contain the exact same SHA256 fingerprint

#### Scenario: Recurring source creates recurring target

- **WHEN** the source event has `isRecurring: true`, `eventId: "100"`, `instanceId: "100"`, and `recurrenceRule: "FREQ=WEEKLY;BYDAY=MO"`
- **THEN** the target event is created with the same recurrence rule
- **AND** the description includes the sync marker

#### Scenario: Non-recurring source creates non-recurring target

- **WHEN** the source event has `isRecurring: false`
- **THEN** the target event is created without recurrence fields
- **AND** the description includes the sync marker
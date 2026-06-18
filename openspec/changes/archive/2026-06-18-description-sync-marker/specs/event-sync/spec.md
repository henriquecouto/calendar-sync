# event-sync (delta)

## MODIFIED Requirements

### Requirement: Create synced event with user-provided name
The system SHALL create a target event using the user-configured sync name (not the original event title). The target event SHALL copy the source event's start time and end time. The target event's description SHALL be set to the original source event title followed by a sync marker in the format:

```
<original title>
---
🔃 Automatically created by CalSync
```

If the source event is recurring (`isRecurring == true`), the target event SHALL also be created as recurring, copying the source event's `recurrenceRule`.

#### Scenario: Synced event uses custom name and embeds sync marker
- **WHEN** the user has configured "Busy" as the sync name and a source event titled "Doctor Appointment" with eventId "evt-001" appears
- **THEN** the target event has title "Busy", same start/end times as source
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

### Requirement: Skip source events that were created by sync engine
The system SHALL check the description of every source event for the sync marker `"🔃 Automatically created by CalSync"` before classifying it. If the description contains the marker, the system SHALL skip the event to prevent sync loops. The system SHALL also maintain the `sync_created_events` table as a secondary check for cases where the description may be unavailable or truncated. When a target event is deleted (orphan processing, profile deletion, or update replacement), the corresponding row in `sync_created_events` SHALL be removed.

The check order in `_classifySingle` SHALL be:
1. Check description for sync marker → skip if present
2. Check `sync_created_events` table → skip if present (defense-in-depth)
3. Check mapping table → classify as create/update/skip

#### Scenario: Event created by another profile is skipped via description marker
- **WHEN** Profile A creates a target event with description containing "🔃 Automatically created by CalSync"
- **AND** Outlook re-syncs the event, changing its `eventId` from "TGT-100" to "TGT-200"
- **AND** Profile B lists the event in the source calendar with the new `eventId`
- **THEN** Profile B checks the description, finds the marker, and skips it
- **AND** no loop occurs

#### Scenario: User-created event is NOT skipped (no marker)
- **WHEN** the user manually creates "Reunião 10h" in the Work calendar
- **AND** the description does not contain the sync marker
- **THEN** the event SHALL be classified normally (create or skip based on mapping)

#### Scenario: Event created by sync with intact eventId is still skipped via description
- **WHEN** `sync_created_events` has `(Work, evt-100)` and the description also contains the marker
- **THEN** the event is skipped by the description check (first priority)

#### Scenario: Marker detection when description is null
- **WHEN** a source event has `description: null`
- **THEN** the system SHALL NOT crash on null description
- **AND** SHALL fall through to the `sync_created_events` table check

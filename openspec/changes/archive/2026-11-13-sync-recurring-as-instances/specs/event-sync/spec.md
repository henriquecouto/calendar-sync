# event-sync — Delta Spec

## MODIFIED Requirements

### Requirement: Detect already-synced events
The system SHALL query the local mapping table to determine whether a source event (identified by profile ID + source calendar ID + source event ID + source instance ID, where `source_instance_id` is NULL for non-recurring events and the occurrence's `instanceId` for occurrences of recurring series) has already been synced to a target calendar for a given profile. If already synced, the system SHALL compare the source event's start time, end time, and title with the target event's fields and update the target event if any differ. If the target event's start or end time is null, the system SHALL skip the event. If no fields differ, the event is skipped. When comparing the source event's title against the target event's description, the system SHALL use `contains` (not `startsWith` or exact match) to handle descriptions that may be wrapped in HTML by calendar providers.

#### Scenario: Event is already synced with no changes
- **WHEN** a source event's (profile_id, calendar_id, event_id, instance_id) pair exists in the mapping table and its start, end, and title match the target event
- **THEN** the system skips that event

#### Scenario: Event is already synced with time change
- **WHEN** a source event's (profile_id, calendar_id, event_id, instance_id) pair exists in the mapping table and its start or end time differ from the target event
- **THEN** the target event is updated with the new times

#### Scenario: Event is already synced with title change
- **WHEN** a source event's (profile_id, calendar_id, event_id, instance_id) pair exists in the mapping table and its title is NOT contained anywhere in the target event's description
- **THEN** the target event's description is updated to the new source title

#### Scenario: HTML-wrapped description is recognized as unchanged
- **WHEN** the target event's description is `<html><body>Doctor Appointment<br>---<br>🔃 Automatically created by CalSync</body></html>`
- **AND** the source event's title is `Doctor Appointment`
- **THEN** the system SHALL detect no title change via `contains("Doctor Appointment")`
- **AND** the event SHALL be skipped if no other fields changed

#### Scenario: Event is not yet synced
- **WHEN** a source event's (profile_id, calendar_id, event_id, instance_id) pair is absent from the mapping table
- **THEN** the system marks it for sync and creates a target event

#### Scenario: Target event has null times
- **WHEN** a source event's (profile_id, calendar_id, event_id, instance_id) pair exists in the mapping table and the target event's start or end time is null
- **THEN** the system skips the event without crashing

#### Scenario: Occurrences of the same series are detected independently
- **WHEN** a recurring series "100" has two occurrences with instanceIds "100@t1" and "100@t2"
- **AND** only "100@t1" has a mapping row
- **THEN** the occurrence "100@t1" is treated as already synced
- **AND** the occurrence "100@t2" is treated as not yet synced and SHALL be created

#### Scenario: Moved occurrence is not matched by its old mapping
- **WHEN** an occurrence moves from "100@t1" (mapped) to "100@t2" (new time)
- **AND** the listing contains only "100@t2" for that slot
- **THEN** "100@t2" is not matched by the "100@t1" mapping and SHALL be created as a new target event
- **AND** the old "100@t1" mapping SHALL be handled as an orphan

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

The target event's TITLE SHALL still be derived from the profile's `syncEventName` exactly as before — `omitSourceTitle` affects only the description, never the title. The system SHALL NOT create recurring target events: the target event SHALL NOT carry a `recurrenceRule`, even when the source is an occurrence of a recurring series.

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
  de691f9d29a02d009e10def2bd0c4b8e7fe3eff4e0ef002eadbc329e27882333
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
  de691f9d29a02d009e10def2bd0c4b8e7fe3eff4e0ef002eadbc329e27882333
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

  de691f9d29a02d009e10def2bd0c4b8e7fe3eff4e0ef002eadbc329e27882333
  ---
  🔃 Automatically created by CalSync
  ```
- **AND** "Doctor Appointment" SHALL NOT appear in the description

#### Scenario: Omit source title combined with copy description disabled

- **WHEN** the profile has `omitSourceTitle: true` and `copyDescription: false`
- **AND** the source event has title "Doctor Appointment" and description "Bring documents"
- **THEN** the target event description SHALL be:
  ```
  de691f9d29a02d009e10def2bd0c4b8e7fe3eff4e0ef002eadbc329e27882333
  ---
  🔃 Automatically created by CalSync
  ```
- **AND** neither "Doctor Appointment" nor "Bring documents" SHALL appear in the description

#### Scenario: Omit source title combined with copy description enabled and null source description

- **WHEN** the profile has `omitSourceTitle: true` and `copyDescription: true`
- **AND** the source event has `description: null`
- **THEN** the target event description SHALL be:
  ```
  de691f9d29a02d009e10def2bd0c4b8e7fe3eff4e0ef002eadbc329e27882333
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

#### Scenario: Recurring occurrence creates standalone target event
- **WHEN** the source listing contains an occurrence of a recurring series with `eventId: "100"`, `instanceId: "100@1750000000000"`, and `isRecurring: true`
- **THEN** the target event is created with the occurrence's start/end times
- **AND** the target event SHALL NOT be recurring (no `recurrenceRule`)
- **AND** the description includes the sync marker

#### Scenario: Non-recurring source creates non-recurring target
- **WHEN** the source event has `isRecurring: false`
- **THEN** the target event is created without recurrence fields
- **AND** the description includes the sync marker

### Requirement: Record sync mappings
After successfully creating a target event, the system SHALL insert a row into the mapping table recording (profile_id, source_calendar_id, source_event_id, source_instance_id, target_calendar_id, target_event_id, synced_at). For an occurrence of a recurring series, `source_instance_id` SHALL be the occurrence's `instanceId`. For a non-recurring event, `source_instance_id` SHALL be NULL. The system SHALL NOT store `canonical_time`.

#### Scenario: Mapping recorded after sync
- **WHEN** a source event is synced for profile "abc-123" and a target event is created with ID "TGT-456"
- **THEN** the mapping table contains a row linking profile "abc-123", source event "SRC-123" (calendar 1) to target event "TGT-456" (calendar 2) with the current timestamp

#### Scenario: Occurrence mapping records instance id
- **WHEN** an occurrence with `eventId: "100"` and `instanceId: "100@1750000000000"` is synced
- **THEN** the mapping row SHALL store `source_event_id: "100"` and `source_instance_id: "100@1750000000000"`

#### Scenario: Non-recurring mapping has null instance id
- **WHEN** a non-recurring source event is synced
- **THEN** the mapping row SHALL store `source_instance_id: NULL`

#### Scenario: Duplicate mapping prevented within same profile
- **WHEN** the same source event (same event id and instance id) is encountered twice for the same profile before the first sync completes
- **THEN** the UNIQUE constraint on (profile_id, source_calendar_id, source_event_id, source_instance_id) prevents a duplicate mapping and a second target event is not created

#### Scenario: Two occurrences of the same series map independently
- **WHEN** two occurrences of series "100" with instanceIds "100@t1" and "100@t2" are synced
- **THEN** two mapping rows SHALL exist, one per instance id
- **AND** both rows SHALL share `source_event_id: "100"`

#### Scenario: Same event synced by different profiles is allowed
- **WHEN** a source event "SRC-123" on calendar "CAL-A" is synced by profile "P1" to calendar "CAL-B"
- **AND** the same source event "SRC-123" on calendar "CAL-A" is synced by profile "P2" to calendar "CAL-C"
- **THEN** both profiles SHALL have independent mapping rows in the table without conflict

#### Scenario: Mapping removed on source event deletion
- **WHEN** a source event "SRC-789" with mapping for profile "abc-123" to target event "TGT-012" is deleted from the source calendar
- **THEN** the mapping row is removed after the target event is deleted

### Requirement: Run full sync cycle
The system SHALL execute a sync cycle for a given profile: list source events from now to now plus the profile's configured sync window, query the mapping table filtered by profile ID and source calendar, and classify each listed source event individually by its (source_event_id, source_instance_id) pair. For each mapped source event absent from the listing, the system SHALL check the target event's end time against a 7-day threshold. If the target event's end time is more than 7 days in the past, the system SHALL keep it. If the target event's end time is within 7 days, the system SHALL resolve the orphan: if the mapping has a non-null `source_instance_id`, the system SHALL fetch the series master by `source_event_id` — if the master exists, the occurrence was moved or deleted as an exception, and the system SHALL delete the target event and remove its mapping; if the master is gone, the whole series was deleted, and the system SHALL delete the target event and remove its mapping. If the mapping has a null `source_instance_id` (non-recurring event), the system SHALL fetch the source event by ID: if found, re-classify it (update/create path); if not found, delete the target event and remove its mapping. The system SHALL create target events for unmapped source events, update target events for already-synced source events whose fields changed, and record new mappings with the profile ID. Occurrences of recurring series SHALL be classified directly; the series master is fetched only during orphan resolution, never to create a recurring target event.

#### Scenario: Full sync with new events
- **WHEN** the source calendar has 3 events and none are in the mapping table
- **THEN** the system creates 3 target events with the user-provided name and inserts 3 mapping rows

#### Scenario: Full sync with mixed state
- **WHEN** the source calendar has 5 events and 2 are already mapped
- **THEN** the system creates 3 target events for the unmapped ones and skips 2 if unchanged

#### Scenario: Full sync with deleted source event
- **WHEN** the source calendar previously had 3 events (all synced) and now has only 2
- **THEN** the system deletes the target event for the missing source event, removes its mapping, and leaves the other 2 untouched

#### Scenario: Full sync with updated events
- **WHEN** the source calendar has 3 synced events and 2 had their times changed
- **THEN** the system updates 2 target events with the new times and reports them as updated

#### Scenario: Full sync with additions, deletions, and updates
- **WHEN** the source calendar had 4 synced events and now has 3 (1 deleted, 1 new, 1 modified, 1 unchanged)
- **THEN** the system deletes 1, creates 1, updates 1, and skips 1

#### Scenario: Full sync scoped to correct profile
- **WHEN** profile "P1" syncs from calendar "CAL-A" and profile "P2" syncs from calendar "CAL-A"
- **AND** profile "P1" has existing mappings for events on "CAL-A"
- **THEN** profile "P2" SHALL NOT see profile "P1"'s mappings and SHALL classify its own source events independently

#### Scenario: Full sync with recurring event expands to instances
- **WHEN** the source calendar has a recurring event "Weekly Standup" (base ID "100", 5 instances in window)
- **THEN** the system creates 5 independent target events, one per instance
- **AND** no target event SHALL be recurring
- **AND** 5 mapping rows SHALL be recorded, one per instance id

#### Scenario: Moved occurrence is deleted from old slot and created at new time
- **WHEN** an occurrence of series "100" previously at "100@t1" (mapped, target in the future) moves to "100@t2" in the next cycle
- **AND** the series master still exists
- **THEN** the system deletes the target event for "100@t1" and removes its mapping
- **AND** the system creates a new target event for "100@t2" and records a new mapping

#### Scenario: Deleted occurrence is removed from target
- **WHEN** one occurrence of series "100" is deleted as an exception (no longer listed)
- **AND** the series master still exists
- **AND** the orphaned occurrence's target event is in the future
- **THEN** the system deletes that occurrence's target event and removes its mapping
- **AND** other occurrences of the series are unaffected

#### Scenario: Deleted series removes all its instances
- **WHEN** the recurring series "100" is deleted from the source calendar
- **AND** 3 occurrence mappings exist with target events in the future
- **THEN** the system deletes all 3 target events and removes all 3 mappings

#### Scenario: Aged-out occurrence is kept
- **WHEN** a synced occurrence is absent from the listing because it fell out of the window
- **AND** its target event's end time is more than 7 days in the past
- **THEN** the system does NOT delete the target event and does NOT remove its mapping

#### Scenario: Old past event is ignored
- **WHEN** a synced source event is absent from the fetch window AND its target event's end time is more than 7 days in the past
- **THEN** the system does NOT delete the target event

#### Scenario: Recent past event with source still existing (edited outside window)
- **WHEN** a synced source event is absent from the fetch window AND its target event's end time is within 7 days
- **AND** the source event still exists (found via getEvent by ID) — e.g., it was edited to a past date outside the fetch window
- **THEN** the system re-classifies the source event (updates target if fields changed, skips if unchanged)
- **AND** does NOT delete the target event

#### Scenario: Recent past event with source truly deleted
- **WHEN** a synced source event is absent from the fetch window AND its target event's end time is within 7 days
- **AND** the source event is genuinely gone (getEvent by ID returns null)
- **THEN** the system deletes the target event and removes the mapping

#### Scenario: Orphan mapping with missing target event
- **WHEN** a synced source event is absent from the fetch window AND the target event no longer exists in the target calendar
- **THEN** the system removes the orphan mapping without error

#### Scenario: Full sync uses profile sync window
- **WHEN** a profile has a sync window of 90 days
- **THEN** the source listing SHALL cover from now to now+90 days
- **AND** occurrences within that horizon SHALL be classified

## ADDED Requirements

### Requirement: Database schema includes source_instance_id
The `sync_mappings` table SHALL include a nullable `source_instance_id TEXT` column. The uniqueness constraint SHALL be `UNIQUE(profile_id, source_calendar_id, source_event_id, source_instance_id)`. The `sync_profiles` table SHALL include a `sync_window_days INTEGER NOT NULL DEFAULT 30` column.

#### Scenario: source_instance_id stored for occurrences
- **WHEN** a target is created for a recurring occurrence with instanceId "100@1750000000000"
- **THEN** the mapping row stores source_instance_id="100@1750000000000"

#### Scenario: source_instance_id is null for non-recurring events
- **WHEN** a target is created for a non-recurring source event
- **THEN** the mapping row has source_instance_id=null

#### Scenario: sync_window_days stored per profile
- **WHEN** a profile is created with a 3-month window
- **THEN** the profile row stores sync_window_days=90

### Requirement: Migrate legacy recurring mappings lazily
On the first sync cycle after the upgrade, when the engine encounters a mapping row with `source_instance_id` NULL whose `source_event_id` appears in the listing as a recurring occurrence (`eventId != instanceId`), the system SHALL delete the mapped target event (the legacy recurring series), remove the mapping row, and classify the listed occurrences as new events. Legacy mappings for non-recurring source events SHALL be left untouched.

#### Scenario: Legacy series mapping replaced by per-instance mappings
- **WHEN** a legacy mapping row (source_instance_id NULL, source_event_id "100") exists pointing at a recurring target series
- **AND** the listing contains 3 occurrences of series "100"
- **THEN** the legacy target series is deleted and its mapping removed
- **AND** 3 independent target events are created, one per occurrence

#### Scenario: Legacy non-recurring mapping untouched
- **WHEN** a legacy mapping row (source_instance_id NULL) points at a non-recurring source event
- **AND** that event is listed normally
- **THEN** the mapping is treated as already synced and no deletion occurs

#### Scenario: Failed legacy deletion keeps mapping for retry
- **WHEN** deleting the legacy target series fails
- **THEN** the mapping row is NOT removed
- **AND** the next sync cycle retries the legacy migration

## REMOVED Requirements

### Requirement: Skip recurring event instances
**Reason**: Recurring occurrences are now classified individually as independent events; the master is no longer fetched to synthesize a recurring target event.
**Migration**: The engine no longer fetches the base event during classification; each listed occurrence is classified by its own (eventId, instanceId) pair.

### Requirement: Database schema includes canonical_time
**Reason**: Time-of-day comparison against a stored canonical time is replaced by direct per-occurrence start/end comparison; occurrences whose time changes also change instance id and are handled as move (delete + create).
**Migration**: The `canonical_time` column may remain in the schema (nullable) for backwards compatibility but is no longer written or read by the engine.

### Requirement: CalendarService supports recurrence parameter
**Reason**: The engine no longer creates recurring target events, so the `recurrenceRule` parameter of `CalendarService.createEvent` becomes dead code.
**Migration**: Remove the `recurrenceRule` parameter from `CalendarService.createEvent` and its call sites.

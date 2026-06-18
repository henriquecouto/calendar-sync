# event-sync (delta)

## MODIFIED Requirements

### Requirement: Record sync mappings
After successfully creating a target event, the system SHALL insert a row into the mapping table recording (profile_id, source_calendar_id, source_event_id, target_calendar_id, target_event_id, synced_at). If the source event is recurring, the system SHALL also store the `HH:mm` of the source's `startDate` as `canonical_time`.

### Requirement: Skip recurring event instances
When a source event is an instance of a recurring event (`eventId != instanceId`), the system SHALL fetch the base recurring event by `eventId` once per sync cycle and classify it instead of the instance. When comparing the merged event against an already-synced target, the system SHALL compare only the time-of-day (`HH:mm`) of `startDate` against the stored `canonical_time` in the mapping, ignoring the date component. Title changes and recurrence rule changes are still detected as before.

#### Scenario: Recurring event unchanged across cycles is skipped
- **WHEN** a recurring event "100" is already synced with canonical_time "10:00"
- **AND** in a later cycle the earliest instance has start=2026-06-19 10:00
- **THEN** HH:mm "10:00" matches canonical_time "10:00" → timeChanged is false → event is skipped

#### Scenario: User changes recurring event time detected
- **WHEN** a recurring event "100" is already synced with canonical_time "10:00"
- **AND** the user changes the recurring event start time to 14:00
- **THEN** the next cycle's earliest instance has HH:mm "14:00" → differs from canonical_time "10:00" → timeChanged is true → UPDATE

#### Scenario: Non-recurring event time comparison unchanged
- **WHEN** a non-recurring event is compared against the target
- **THEN** the full `millisecondsSinceEpoch` comparison is used (existing behavior)

### Requirement: Database schema includes canonical_time
The `sync_mappings` table SHALL include a nullable `canonical_time TEXT` column. This column is set when a target event is created for a recurring source and used for time-of-day comparison during subsequent syncs.

#### Scenario: canonical_time stored for recurring events
- **WHEN** a target is created for a recurring source event with start=10:00
- **THEN** the mapping row stores canonical_time="10:00"

#### Scenario: canonical_time is null for non-recurring events
- **WHEN** a target is created for a non-recurring source event
- **THEN** the mapping row has canonical_time=null

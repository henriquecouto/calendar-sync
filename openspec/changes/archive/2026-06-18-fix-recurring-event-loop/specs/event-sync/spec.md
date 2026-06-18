# event-sync (delta)

## MODIFIED Requirements

### Requirement: Create synced event with user-provided name
The system SHALL create a target event using the user-configured sync name (not the original event title). The target event SHALL copy the source event's start time and end time. The target event's description SHALL be set to the original source event title. If the source event is recurring (`isRecurring == true` and `eventId == instanceId`), the target event SHALL also be created as recurring, copying the source event's `recurrenceRule`.

#### Scenario: Synced event uses custom name and preserves source title as description
- **WHEN** the user has configured "Busy" as the sync name and a source event titled "Doctor Appointment" appears
- **THEN** the target event has the title "Busy", the same start/end times as the source event, and description "Doctor Appointment"

#### Scenario: Recurring source creates recurring target
- **WHEN** the source event has `isRecurring: true`, `eventId: "100"`, `instanceId: "100"`, and `recurrenceRule: "FREQ=WEEKLY;BYDAY=MO"`
- **THEN** the target event is created with the same recurrence rule

#### Scenario: Non-recurring source creates non-recurring target
- **WHEN** the source event has `isRecurring: false`
- **THEN** the target event is created without recurrence fields

### Requirement: Run full sync cycle
The system SHALL execute a sync cycle for a given profile: list source events (from now to now+30d), query mapping table filtered by profile ID and source calendar, for each mapped source event absent from the fetch window check the target event's end time against a 7-day threshold (skip if older, confirm via source-by-ID if recent), create target events for unmapped source events, update target events for already-mapped source events whose fields changed, and record new mappings with the profile ID. Recurring event instances (`eventId != instanceId`) whose base event is already mapped SHALL be skipped.

#### Scenario: Full sync with recurring event
- **WHEN** the source calendar has a recurring event "Weekly Standup" (base ID "100", 5 instances in window)
- **THEN** the system creates exactly 1 target recurring event for the base "100"
- **AND** all 5 instances are skipped

## ADDED Requirements

### Requirement: Skip recurring event instances
When a source event is an instance of a recurring event (`eventId != instanceId`), the system SHALL check whether the base recurring event (identified by `eventId`) is already mapped for this profile. If the base event is NOT mapped, the system SHALL fetch the base event by ID and classify it (using the instance's start/end times but the base's recurrence rule). If the base event IS mapped, the system SHALL still fetch the base event once per sync cycle and classify it to detect time or title changes (which would trigger an update). The instance itself is never directly classified as CREATE or UPDATE.

#### Scenario: Instance of already-synced recurring event is skipped but base is checked
- **WHEN** a recurring base event "100" is already mapped
- **AND** an instance appears with `eventId: "100"` and `instanceId: "100@timestamp"`
- **THEN** the instance is skipped
- **AND** the base event "100" is fetched and classified to detect changes (time/title)

#### Scenario: Instance of unsynced recurring event triggers base sync
- **WHEN** a recurring base event "100" is NOT yet mapped
- **AND** an instance appears with `eventId: "100"` and `instanceId: "100@timestamp"`
- **THEN** the base event "100" is fetched and classified as toCreate using the instance's start/end times and the base's recurrence rule

#### Scenario: Changed recurring event detected via instance
- **WHEN** a recurring event "100" is already synced with start=10:00 end=11:00
- **AND** the user changes it to start=14:00 end=15:00
- **AND** instances appear in the next sync cycle
- **THEN** the base event is fetched, time change is detected, and the target is updated

#### Scenario: Non-recurring event is classified normally
- **WHEN** a source event has `eventId == instanceId`
- **THEN** the system classifies it normally using existing mapping checks

### Requirement: CalendarService supports recurrence parameter
The `CalendarService.createEvent()` method SHALL accept an optional `RecurrenceRule? recurrenceRule` parameter. When provided, it SHALL be passed to the `device_calendar_plus` plugin's `createEvent` call.

#### Scenario: Recurrence rule passed to plugin
- **WHEN** `createEvent` is called with `recurrenceRule: WeeklyRecurrence(daysOfWeek: [DayOfWeek.monday])`
- **THEN** the plugin creates a recurring event with the given recurrence rule

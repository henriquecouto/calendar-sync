## ADDED Requirements

### Requirement: All-day source events create all-day target events
The system SHALL copy all-day source events as all-day target events, preserving the source event's `startDate`, `endDate`, and `isAllDay` flag without date projection or time stripping. The `device_calendar_plus` plugin already uses half-open intervals `[startDate, endDate)` for all-day events, so no conversion is needed.

#### Scenario: Single-day all-day copied as all-day
- **WHEN** the source event is all-day with startDate=2026-06-23, endDate=2026-06-24
- **THEN** the target event is created with `isAllDay: true`, startDate=2026-06-23, endDate=2026-06-24 (same dates, no projection)

#### Scenario: Multi-day all-day copied as all-day
- **WHEN** the source event is all-day with startDate=2026-06-23, endDate=2026-06-26
- **THEN** the target event is created with `isAllDay: true`, startDate=2026-06-23, endDate=2026-06-26

### Requirement: All-day change detection uses uniform timestamp comparison
The system SHALL detect changes in all-day events using the same `millisecondsSinceEpoch` comparison as timed events, without a special branch for all-day duration logic.

#### Scenario: All-day with matching start/end is skipped
- **WHEN** source all-day event has startDate=A, endDate=B
- **AND** target all-day event has startDate=A, endDate=B and description matches
- **THEN** the event is skipped (no change detected)

#### Scenario: All-day with date change is updated
- **WHEN** source all-day event has startDate changed
- **AND** target all-day event still has the old startDate
- **THEN** the event is classified as toUpdate, creating a replacement all-day event with the same dates as the source

### Requirement: No date projection helpers
The sync engine SHALL NOT use `_localMidnight` or `_projectEnd` helpers. All-day event dates SHALL pass through from source to target without modification.

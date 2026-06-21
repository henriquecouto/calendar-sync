# Calendar Access

## Purpose

Provide a thin wrapper around the `device_calendar_plus` plugin to retrieve and manipulate calendar events on the device.

## Requirements

### Requirement: List available calendars
The system SHALL retrieve all calendars available on the device via `DeviceCalendar.instance.listCalendars()`, returning at minimum the calendar ID, display name, and writability flag for each. Calendars are returned as a list of `PlatformCalendar` objects. Errors are handled via try/catch on `DeviceCalendarException`.

#### Scenario: Calendars retrieved successfully
- **WHEN** calendar permissions are granted and the user opens the calendar picker
- **THEN** the system displays a list of all device calendars with their display names

#### Scenario: No calendars available
- **WHEN** the device has no calendars configured
- **THEN** the system returns an empty list without crashing

### Requirement: List events for a calendar
The system SHALL retrieve all events for a given calendar ID within a configurable time window (default: 30 days from now) via `DeviceCalendar.instance.listEvents(startDate, endDate, calendarIds: [calendarId])`. Events use native `DateTime` (local time). Each event is represented as a `CalendarEvent` object.

#### Scenario: Events within time window
- **WHEN** the user selects a source calendar and the calendar has events in the next 30 days
- **THEN** the system returns all events with their ID, title, start time, end time, and description

#### Scenario: Time-bounded query
- **WHEN** the system queries events for the next 30 days
- **THEN** events outside that window are excluded from results

### Requirement: Retrieve a single event by ID
The system SHALL retrieve a single calendar event by its event ID via `DeviceCalendar.instance.getEvent(eventId)`, without requiring a calendar ID. The retrieval SHALL use a direct ID-based lookup rather than fetching all events and scanning.

#### Scenario: Past event retrieved by ID
- **WHEN** the system requests an event by its ID and the event's start time is in the past
- **THEN** the event is returned with all its fields (ID, title, start, end, description)

#### Scenario: Future event retrieved by ID
- **WHEN** the system requests an event by its ID and the event's start time is in the future
- **THEN** the event is returned with all its fields

#### Scenario: Non-existent event ID
- **WHEN** the system requests an event by an ID that does not exist in the calendar
- **THEN** the system returns null without error

### Requirement: Create an event in a calendar
The system SHALL create a new event in a specified calendar via `DeviceCalendar.instance.createEvent(calendarId:, title:, startDate:, endDate:, description:?, isAllDay:?)`. The method uses named parameters with native `DateTime`. The system SHALL return the new event ID string. Errors throw `DeviceCalendarException`.

#### Scenario: Event created successfully
- **WHEN** the sync engine creates a target event in calendar B with the user-provided name
- **THEN** the event appears in the target calendar and the system returns the new event ID

#### Scenario: Duplicate event name is allowed
- **WHEN** an event with the same title and time already exists in the target calendar
- **THEN** the system still creates the new event and returns a unique event ID

### Requirement: Delete an event from a calendar
The system SHALL delete an event via the Android platform channel method `deleteEvent` on channel `dev.henriquecouto.calsync/calendar`, passing only `eventId`. The platform channel SHALL call `ContentResolver.delete()` on plain `Events.CONTENT_URI`. The Android Calendar Provider SHALL determine the deletion strategy automatically: `DELETED=1` for synced calendars (allowing sync adapters to propagate the deletion), physical row removal for local calendars. The method SHALL NOT use `device_calendar_plus`'s `deleteEvent()` as a fallback.

#### Scenario: Event deleted successfully
- **WHEN** the system deletes a synced event by its target event ID
- **THEN** the event is removed from the target calendar

#### Scenario: Deleting non-existent event
- **WHEN** the system attempts to delete an event ID that no longer exists
- **THEN** the system handles the error gracefully without crashing

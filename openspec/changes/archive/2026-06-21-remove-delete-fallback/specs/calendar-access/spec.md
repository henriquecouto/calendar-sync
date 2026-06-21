## MODIFIED Requirements

### Requirement: Delete an event from a calendar
The system SHALL delete an event via the Android platform channel method `deleteEvent` on channel `dev.henriquecouto.calsync/calendar`, passing only `eventId`. The platform channel SHALL call `ContentResolver.delete()` on plain `Events.CONTENT_URI`. The Android Calendar Provider SHALL determine the deletion strategy automatically: `DELETED=1` for synced calendars (allowing sync adapters to propagate the deletion), physical row removal for local calendars. The method SHALL NOT use `device_calendar_plus`'s `deleteEvent()` as a fallback.

#### Scenario: Event deleted successfully
- **WHEN** the system deletes a synced event by its target event ID
- **THEN** the event is removed from the target calendar

#### Scenario: Deleting non-existent event
- **WHEN** the system attempts to delete an event ID that no longer exists
- **THEN** the system handles the error gracefully without crashing

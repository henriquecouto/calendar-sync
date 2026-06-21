## MODIFIED Requirements

### Requirement: Run full sync cycle
The system SHALL execute a sync cycle for a given profile: list source events (from now to now+30d), query mapping table filtered by profile ID and source calendar, for each mapped source event absent from the fetch window check the target event's end time against a 7-day threshold (skip if older, delete if recent), create target events for unmapped source events, update target events for already-mapped source events whose fields changed, and record new mappings with the profile ID. Recurring event instances (`eventId != instanceId`) are fetched via base event ID and never directly classified; the base event is classified once per cycle instead.

#### Scenario: Old past event is ignored
- **WHEN** a synced source event is absent from the fetch window AND its target event's end time is more than 7 days in the past
- **THEN** the system does NOT delete the target event

#### Scenario: Recent past event with source deleted
- **WHEN** a synced source event is absent from the fetch window AND its target event's end time is within 7 days
- **THEN** the system deletes the target event and removes the mapping without re-fetching the source event by ID

### Requirement: Soft-delete target events for sync adapter propagation
The system SHALL delete target events by setting `DELETED=1` and `DIRTY=1` on the Android Calendar Provider event row, using a sync-adapter context URI (`CALLER_IS_SYNCADAPTER=true`) so the Calendar Provider allows writing to the `DIRTY` field. After marking the event, the system SHALL call `ContentResolver.requestSync()` for all device accounts to trigger immediate sync adapter propagation. This ensures sync adapters (e.g., DAVdroid) detect the deletion and push it to the remote server.

The soft-delete operation SHALL be implemented as a native FlutterPlugin (`SoftDeletePlugin`) registered in `GeneratedPluginRegistrant.java` via a Gradle build task, making it available in both foreground and background Flutter engines.

#### Scenario: Target event soft-deleted on source deletion
- **WHEN** a source event is deleted from the source calendar
- **AND** the sync engine detects the orphaned mapping
- **THEN** the target event row is updated with `DELETED=1` and `DIRTY=1` using sync-adapter context URI
- **AND** `ContentResolver.requestSync()` is called for all accounts
- **AND** the mapping is removed from the local database

#### Scenario: Soft-delete works in background sync
- **WHEN** the Workmanager periodic task triggers a sync
- **AND** an orphaned mapping is detected requiring target deletion
- **THEN** the SoftDeletePlugin is available via the background FlutterEngine's GeneratedPluginRegistrant
- **AND** the soft-delete proceeds without falling back to hard-delete

### Requirement: Hard-delete fallback with post-deletion verification
If the soft-delete MethodChannel is unavailable, the system SHALL fall back to the `device_calendar_plus` plugin's hard-delete. After a hard-delete, the system SHALL wait 5 seconds and then call `getEvent` on the target event ID. If the event still exists (the provider restored it), the system SHALL NOT remove the mapping, allowing a retry on the next sync cycle.

#### Scenario: Hard-delete fallback with successful verification
- **WHEN** soft-delete fails and hard-delete is used
- **AND** 5 seconds after deletion, `getEvent` returns null (event is gone)
- **THEN** the mapping is removed

#### Scenario: Hard-delete fallback with event restoration
- **WHEN** soft-delete fails and hard-delete is used
- **AND** 5 seconds after deletion, `getEvent` still returns the event (provider restored it)
- **THEN** the mapping is preserved for retry on the next sync cycle
- **AND** an error is recorded

## REMOVED Requirements

### Requirement: Source event re-verification via getEvent
**Reason**: Android Calendar Provider soft-deletes events by marking `DELETED=1`. The `listEvents` API filters these out (correctly indicating deletion), but `getEvent` still returns them. The re-verification was intended to prevent false-positive deletions but caused false negatives: legitimately deleted source events were re-found by `getEvent` and classified as "still exists", blocking target deletion indefinitely.
**Migration**: Orphan detection now trusts `listEvents` exclusively. If a mapped source event is absent from `listEvents`, it is considered deleted and the target is deleted without further verification.

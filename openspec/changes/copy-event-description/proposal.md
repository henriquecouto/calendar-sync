## Why

Currently, when events are synced from a source calendar to a target calendar, only the event's title and times are carried over. The source event's description, location, and other metadata are discarded. Users want the option to preserve the source event's description and location in the synced target event so they don't lose context (meeting notes, links, agenda details, room/location info, etc.).

## What Changes

- Add two new boolean fields to each sync profile: `copyDescription` and `copyLocation`, both defaulting to `false`.
- When `copyDescription` is enabled, the sync engine prepends the source event's description to the target event's description (above the existing sync marker block).
- When `copyLocation` is enabled, the target event inherits the source event's location. When disabled, the target event has no location.
- `CalendarService.createEvent()` gains an optional `location` parameter passed through to the `device_calendar_plus` plugin.
- Restructure the profile config screen into **Basic** and **Advanced** sections:
  - **Basic**: Profile name, source/target calendar pickers, sync enabled toggle
  - **Advanced** (collapsed by default): Sync event name, fallback interval, copy location toggle, copy description toggle
- Update the database schema (`sync_profiles` table) to include `copy_description` and `copy_location` columns (migration for existing profiles).

## Capabilities

### New Capabilities
- `copy-event-details`: Optionally copy the source event's description and/or location into the synced target event. Two independent toggles control each field.

### Modified Capabilities
- `sync-profiles`: Profile data model gains `copyDescription` and `copyLocation` boolean fields. The profile form is reorganized into Basic/Advanced sections with field moves. Create and edit profiles accept the new fields.
- `event-sync`: `CalendarService.createEvent()` accepts an optional `location` parameter. The sync engine passes `event.location` (or null) to `createEvent` based on `copyLocation`. Target description assembly is conditional on `copyDescription`.

## Impact

- **Database**: `sync_profiles` table gets `copy_description` and `copy_location` columns (`INTEGER NOT NULL DEFAULT 0`). Existing profiles default to `0` (disabled).
- **ProfileService**: CRUD operations read/write both new fields.
- **Profile model**: New `bool copyDescription` and `bool copyLocation` properties.
- **CalendarService**: `createEvent()` adds optional `String? location` parameter.
- **Sync engine**: Accepts `copyDescription` and `copyLocation`; passes location through; uses `buildDescription()` for description assembly.
- **UI**: Profile form reorganized into Basic/Advanced sections. Three fields move (sync event name, fallback interval, sync enabled). Two new toggles added (copy location, copy description).
- **No breaking changes**: Both fields default to `false`, matching current behavior.

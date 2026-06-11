## Why

Users need confidence that sync will behave correctly before modifying calendar data. A dry run shows exactly which events would be synced, skipped, or deleted — without touching any calendar. This reduces anxiety about unintended side effects and helps validate configuration.

## What Changes

- New "Dry Run" screen navigable from the home page
- Dry run engine that mirrors sync detection logic but creates no calendar events and inserts no mappings
- Display of source events split into three categories: would be synced (new), would be skipped (already mapped), and would be deleted (orphaned target events)
- For "would be synced" events, show what the target event would look like (title = user's sync name, description = source title, matching start/end times)
- No writes to the mapping database or any calendar during dry run

## Capabilities

### New Capabilities
- `dry-run-sync`: Preview what a sync cycle would do — which source events would be synced, which would be skipped, and which target events would be deleted — without modifying any calendar data or mapping records.

### Modified Capabilities
<!-- None -->

## Impact

- Affected code: new `lib/sync/dry_run_engine.dart`, new `lib/sync/dry_run_screen.dart`, modified `lib/main.dart` (add navigation entry point)
- No API or dependency changes
- No changes to existing sync engine, calendar service, or mapping database
- No calendar permissions beyond what's already required

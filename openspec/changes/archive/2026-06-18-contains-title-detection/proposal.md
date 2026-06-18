## Why

Outlook and other Exchange ActiveSync providers convert event descriptions to HTML format (e.g., `<html><body>Title<br>---<br>🔃 CalSync</body></html>`). The current `startsWith` comparison for title change detection breaks on HTML-wrapped descriptions, causing false UPDATEs every sync cycle.

## What Changes

- Replace `startsWith` with `contains` when comparing `event.title` against `targetEvent.description` in `_classifySingle`
- Description marker check also uses `contains` (already does, no change needed)

## Capabilities

### New Capabilities

- (none)

### Modified Capabilities

- `event-sync`: REQUIREMENT "Detect already-synced events" — title comparison must use `contains` instead of `startsWith` to handle HTML-wrapped descriptions

## Impact

- `lib/sync/sync_engine.dart`: change one comparison in `_classifySingle`
- `test/sync_engine_test.dart`: update assertion for title detection test

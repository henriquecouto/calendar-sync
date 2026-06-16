## Why

The `SyncEngine._classify` method has grown to ~170 lines with duplicated all-day projection logic across `_classify` and `_execute`. Extraction improves readability and reduces maintenance risk.

## What Changes

- Extract `_projectAllDayTimes(Event)` helper — 6-line block duplicated in `_classify` and `_execute` update path
- Split `_classify` into `_handleOrphanMappings()` and `_classifySourceEvents()`

## Capabilities

### New Capabilities

<!-- None — pure refactor -->

### Modified Capabilities

<!-- None — no requirement changes -->

## Impact

- `lib/sync/sync_engine.dart` — method extraction only, zero behavior change

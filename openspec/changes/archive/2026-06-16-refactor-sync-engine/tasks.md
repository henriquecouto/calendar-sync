## 1. Safety net — add tests for uncovered branches

- [x] 1.1 `_execute` create path: verify `createEvent` is called with correct projected values
- [x] 1.2 `_execute` update path: verify old event is deleted and new event is created
- [x] 1.3 `_execute` delete path: verify `deleteEvent` and `deleteMapping` are called
- [x] 1.4 `runSync` errors path: when `plan.errors` is non-empty, returns early with empty results
- [x] 1.5 Orphan mapping: target event is `null` → mapping deleted, no crash
- [x] 1.6 Orphan mapping: all-day target with `end=null` → mapping preserved, not deleted

## 2. Extract all-day projection helper

- [x] 2.1 Add `static TZDateTime _projectEnd(Event event)` method using `_localMidnight` + 1 day
- [x] 2.2 Replace duplicated logic in `_classify` create path with the helper
- [x] 2.3 Replace duplicated logic in `_execute` update path with the helper

## 3. Split _classify into smaller methods

- [x] 3.1 Extract orphan mapping loop into `_processOrphanMappings(...)`
- [x] 3.2 Keep `_classify` as the orchestrator

## 4. Verification

- [x] 4.1 Run `flutter analyze` — no new issues
- [x] 4.2 Run `flutter test` — all tests pass

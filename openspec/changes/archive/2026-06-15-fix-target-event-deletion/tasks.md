## 1. Calendar Service — Revert lookback

- [x] 1.1 Remove `lookbackDays` parameter from `listEvents()`, revert to `startDate: now`

## 2. Sync Engine — 7-day threshold + source-by-ID confirmation

- [x] 2.1 In the deletion pass, for each mapping absent from fetch: fetch target event by ID
- [x] 2.2 If target is null: clean up orphan mapping
- [x] 2.3 If `targetEvent.end < now - 7d`: skip (old event, ignore)
- [x] 2.4 If `targetEvent.end >= now - 7d`: fetch source by ID
- [x] 2.5 If source exists: add to classification loop (re-classify)
- [x] 2.6 If source is null: add to toDelete

## 3. Sync Engine — Null safety for target event times

- [x] 3.1 In the comparison block, add null-guard for `targetEvent.start` and `targetEvent.end` before dereferencing
- [x] 3.2 Skip events with null target times and emit a log entry

## 4. Tests

- [x] 4.1 Write unit test: old past event (target.end < now-7d) is skipped, no source fetch
- [x] 4.2 Write unit test: recent past event with source exists → re-classified, not deleted
- [x] 4.3 Write unit test: recent past event with source gone → deleted
- [x] 4.4 Write unit test: target event with null start/end is skipped without crashing

## 5. Verification

- [x] 5.1 Run `flutter analyze` — confirm no new warnings or errors
- [x] 5.2 Run `flutter test` — confirm all tests pass

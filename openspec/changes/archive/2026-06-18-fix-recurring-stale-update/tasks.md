## 1. Database Schema

- [x] 1.1 Add `canonical_time TEXT` column to `sync_mappings` in `DatabaseProvider._init()` onCreate and onUpgrade
- [x] 1.2 Update `MappingDatabase.insertMapping()` to accept optional `canonicalTime` parameter

## 2. Sync Engine

- [x] 2.1 In `_execute()` create path: when creating target for recurring event, extract `HH:mm` from `startDate` and pass as `canonicalTime` to `insertMapping()`
- [x] 2.2 In `_classifySingle()`: for recurring events (base mapped), compare `HH:mm` of `startDate` against mapping's `canonical_time` instead of full `millisecondsSinceEpoch`
- [x] 2.3 Revert "earliest instance" pre-computation (remove `earliestInstance` map)

## 3. Tests & Cleanup

- [x] 3.1 Add test: recurring event with same HH:mm across cycles is skipped
- [x] 3.2 Add test: recurring event with changed HH:mm is updated
- [x] 3.3 Add test: non-recurring event still uses full timestamp comparison
- [x] 3.4 Run `flutter analyze` and `flutter test`

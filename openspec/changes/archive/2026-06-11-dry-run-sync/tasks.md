## 1. Data Models

- [x] 1.1 Create `SyncPlan` model with fields: toCreate (list of source event + projected target details), toUpdate (list of source event + existing mapping), toSkip (list of source event), toDelete (list of orphaned mappings), errors (list of strings)
- [x] 1.2 Add `ProjectedEvent` fields (title, description, start, end) within `SyncPlan.toCreate` entries

## 2. SyncEngine Refactor

- [x] 2.1 Extract classification logic from `runSync()` into a private `_classify()` method that returns a `SyncPlan` (reads only, no mutations)
- [x] 2.2 Extract execution logic from `runSync()` into a private `_execute(SyncPlan)` method (applies calendar/mapping writes)
- [x] 2.3 Refactor `runSync()` to call `_classify()` then `_execute()`, returning the same `SyncResult` (public API unchanged)
- [x] 2.4 Add public `runDryRun()` method that calls `_classify()` and returns the `SyncPlan` directly (no mutations)
- [x] 2.5 Handle classification errors gracefully (missing calendar IDs, empty sync name, empty source calendar) — partial results returned in `SyncPlan.errors`

## 3. Dry Run Screen

- [x] 3.1 Create `DryRunScreen` StatefulWidget in `lib/sync/dry_run_screen.dart`
- [x] 3.2 Implement "Run Dry Run" button that calls `SyncEngine.runDryRun()` with loading indicator
- [x] 3.3 Display toCreate section showing source event title and projected target event details (title, description, start/end)
- [x] 3.4 Display toSkip section showing source event title and time
- [x] 3.5 Display toDelete section showing source event title from orphaned mappings
- [x] 3.6 Display toUpdate section showing source event title and what changed
- [x] 3.7 Show empty state when no dry run has been executed yet
- [x] 3.8 Show dry run execution timestamp on screen

## 4. Navigation Integration

- [x] 4.1 Add a dry run icon button to HomePage AppBar (alongside existing history button)
- [x] 4.2 Disable dry run button when sync is disabled (consistent with "Sync Now" button behavior)
- [x] 4.3 Navigate to `DryRunScreen` on button press
- [x] 4.4 Remove sync-enabled gating from dry run button — dry run available regardless of sync setting

## 5. Verification

- [x] 5.1 Run `flutter analyze` and fix any warnings
- [x] 5.2 Run `flutter test` and ensure existing tests still pass
- [x] 5.3 Manual test: verify dry run shows correct categories without modifying calendar data

## 1. Dependency

- [x] 1.1 Add `crypto: ^3.0.0` to `dependencies` in `pubspec.yaml`
- [x] 1.2 Run `flutter pub get` to fetch the new dependency

## 2. Database schema (v7 → v8)

- [x] 2.1 Add `_columnOmitSourceTitle = 'omit_source_title'` constant and `omit_source_title INTEGER NOT NULL DEFAULT 0` column to the `CREATE TABLE sync_profiles` statement in `DatabaseProvider._init()`
- [x] 2.2 Bump `version: 7` to `version: 8` in `openDatabase`
- [x] 2.3 Add `if (oldVersion < 8)` branch in `onUpgrade` that runs `ALTER TABLE sync_profiles ADD COLUMN omit_source_title INTEGER NOT NULL DEFAULT 0`

## 3. SyncProfile model & ProfileService

- [x] 3.1 Add `final bool omitSourceTitle;` field to `SyncProfile` class with `const` default `false`
- [x] 3.2 Extend `SyncProfile.copyWith` with `bool? omitSourceTitle` parameter
- [x] 3.3 Add `_columnOmitSourceTitle` constant in `ProfileService`
- [x] 3.4 Extend `ProfileService.createProfile` signature with `bool omitSourceTitle = false` and write the new column to the `INSERT`
- [x] 3.5 Extend `ProfileService.updateProfile` to write `omitSourceTitle` to the `UPDATE`
- [x] 3.6 Extend `ProfileService._rowToProfile` to read `omit_source_title` into the new field with default `false`

## 4. SyncEngine

- [x] 4.1 Import `package:crypto/crypto.dart` at the top of `lib/sync/sync_engine.dart`
- [x] 4.2 Extend `buildDescription()` signature with named `bool omitSourceTitle = false` parameter; when true, replace the title line with `sha256.convert(originalTitle.codeUnits).toString()` (keep the `---` separator)
- [x] 4.3 Extend `runSync()` signature with `bool omitSourceTitle = false` and forward it to `_classify` and `_execute`
- [x] 4.4 Extend `runDryRun()` signature with `bool omitSourceTitle = false` and forward it to `_classify`
- [x] 4.5 Extend `_classify()` and `_classifySingle()` to accept and forward `omitSourceTitle` and `copyDescription`
- [x] 4.6 Update `_classifySingle()` change-detection: compute `titleFingerprint` as `sha256(title)` when `omitSourceTitle` is true, else `event.title`; replace `titleChanged` check with `!(targetEvent.description?.contains(titleFingerprint) ?? false)`
- [x] 4.7 Extend `_execute()` signature with `bool omitSourceTitle = false` and forward it to `buildDescription()` in both create and update passes

## 5. UI - profile form

- [x] 5.1 Add `bool _omitSourceTitle = false;` state field in `_ProfileConfigScreenState`
- [x] 5.2 Populate `_omitSourceTitle` from the loaded profile in `_load()`
- [x] 5.3 Pass `omitSourceTitle: _omitSourceTitle` to `createProfile` / `updateProfile` in `_save()`
- [x] 5.4 Add the new `omitSourceTitle` to the `advancedExpanded` derivation so the Advanced section auto-expands when editing a profile that has it on
- [x] 5.5 Add a new `SwitchListTile` titled "Omit source event title" with a privacy-themed hint mentioning the SHA256 fingerprint to the Advanced `ExpansionTile`, after the existing copy toggles

## 6. UI - call sites

- [x] 6.1 Pass `omitSourceTitle: profile.omitSourceTitle` from `dashboard_screen.dart` to `runSync`
- [x] 6.2 Pass `omitSourceTitle: profile.omitSourceTitle` from `background/sync_task.dart` to `runSync`
- [x] 6.3 Pass `omitSourceTitle: profile.omitSourceTitle` from `dry_run_screen.dart` to the sync engine

## 7. Tests

- [x] 7.1 Add `buildDescription` unit tests in `test/sync_engine_test.dart` covering: `omitSourceTitle=true` with `copyDescription=false` produces `<sha256>\n---\n<marker>`; with `copyDescription=true` and non-empty source description produces `<src desc>\n\n<sha256>\n---\n<marker>`; with `copyDescription=true` and null source description; with `copyDescription=true` and empty source description
- [x] 7.2 Add a `buildDescription` test asserting the SHA256 fingerprint matches the well-known hash for empty title (`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`) when the title is empty and `omitSourceTitle=true`
- [x] 7.3 Add a `buildDescription` test asserting the SHA256 fingerprint matches a hardcoded expected value for a known title (locks the algorithm; any change to the hashing approach will fail loudly)
- [x] 7.4 Add `ProfileService` test cases for round-tripping the new `omitSourceTitle` field through `createProfile` → `getProfile` and `updateProfile` → `getProfile`
- [x] 7.5 Add `SyncEngine` integration test asserting that a sync with `omitSourceTitle=true` creates a target event whose description contains the SHA256 fingerprint and not the plaintext source title
- [x] 7.6 Add `SyncEngine` integration test asserting that an existing synced event whose source title changes DOES trigger an update when `omitSourceTitle=true` (the fingerprint differs from the old one in the target)
- [x] 7.7 Add `SyncEngine` integration test asserting that toggling `omitSourceTitle` from false to true for an already-synced profile triggers an update on the next sync (cleanup of plaintext title)
- [x] 7.8 Add `SyncEngine` integration test asserting that toggling `omitSourceTitle` from true to false triggers a replacement (cleanup of fingerprint)

## 8. Quality gates

- [x] 8.1 Run `flutter analyze` and fix all warnings and errors
- [x] 8.2 Run `flutter test` and confirm all new and existing tests pass
- [x] 8.3 Run `flutter build apk --debug` and confirm no build errors
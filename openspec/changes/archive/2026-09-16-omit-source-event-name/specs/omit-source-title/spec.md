## ADDED Requirements

### Requirement: Profile controls source-title omission in description

Each sync profile SHALL have an `omitSourceTitle` boolean field, defaulting to `false`. When `true`, the sync engine SHALL NOT include the source event's title as plaintext in the target event's description. Instead, the title line SHALL be replaced by the **full lowercase hex SHA256 fingerprint** of the source event's title (64 hex characters). The sync marker SHALL still be present. When `false` (the default), the existing behavior is preserved — the source title appears as the first line of the target description.

The SHA256 fingerprint is deterministic (same input always produces same output) but one-way (cannot be reversed to recover the original title). It exists solely as a change-detection signal for the sync engine; it is not a user-visible privacy guarantee on its own.

#### Scenario: Omit source title disabled preserves current behavior

- **WHEN** a profile has `omitSourceTitle: false`
- **AND** the source event has title "Doctor Appointment"
- **THEN** the target event description SHALL be:
  ```
  Doctor Appointment
  ---
  🔃 Automatically created by CalSync
  ```
- **AND** no SHA256 fingerprint SHALL appear in the description

#### Scenario: Omit source title enabled replaces title with SHA256 fingerprint

- **WHEN** a profile has `omitSourceTitle: true`
- **AND** the source event has title "Doctor Appointment"
- **THEN** the target event description SHALL be:
  ```
  e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
  ---
  🔃 Automatically created by CalSync
  ```
- **AND** "Doctor Appointment" SHALL NOT appear anywhere in the target event description
- **AND** "e3b0c44..." (the actual SHA256 of "Doctor Appointment") SHALL appear as the first line

#### Scenario: Omit source title enabled with empty source title

- **WHEN** a profile has `omitSourceTitle: true`
- **AND** the source event has `title: ""`
- **THEN** the target event description SHALL be:
  ```
  e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
  ---
  🔃 Automatically created by CalSync
  ```
- **AND** the SHA256 fingerprint SHALL be the well-known hash of the empty string

#### Scenario: Omit source title persists across app restarts

- **WHEN** a profile is saved with `omitSourceTitle: true` and the app is restarted
- **THEN** the profile SHALL still have `omitSourceTitle: true`

#### Scenario: Omit source title on update path — source title changes

- **WHEN** a source event is already synced with `omitSourceTitle: true`
- **AND** the source event's title changes from "Doctor Appointment" to "Doctor Visit"
- **AND** no other source field changes
- **THEN** the target event SHALL be marked for update on the next sync cycle
- **AND** the new target description SHALL contain the SHA256 of "Doctor Visit", not "Doctor Appointment"

#### Scenario: Omit source title on update path — source title unchanged

- **WHEN** a source event is already synced with `omitSourceTitle: true`
- **AND** the source event's title is unchanged
- **THEN** the target event SHALL be skipped (no replacement created)

#### Scenario: Toggling omit-source-title from false to true triggers cleanup

- **WHEN** a source event is already synced with `omitSourceTitle: false`
- **AND** the target description contains the source title in plaintext (no SHA256)
- **AND** the user enables `omitSourceTitle: true` on the profile
- **AND** the next sync cycle runs
- **THEN** the target event SHALL be replaced with one whose description contains the SHA256 fingerprint instead of the plaintext title

#### Scenario: Toggling omit-source-title from true to false triggers cleanup

- **WHEN** a source event is already synced with `omitSourceTitle: true`
- **AND** the target description contains the SHA256 fingerprint
- **AND** the user disables `omitSourceTitle` on the profile
- **AND** the next sync cycle runs
- **THEN** the target event SHALL be replaced with one whose description contains the source title in plaintext

### Requirement: Profile form Advanced section contains omit-source-title toggle

The profile create/edit form's Advanced section SHALL contain an "Omit source event title" toggle, in addition to the existing sync event name field, fallback interval dropdown, copy location toggle, and copy description toggle. The toggle SHALL default to off for new profiles and SHALL reflect persisted values for existing profiles.

#### Scenario: Omit toggle appears in Advanced section

- **WHEN** the user opens the profile create or edit form
- **THEN** the Advanced section SHALL contain an "Omit source event title" toggle
- **AND** the toggle SHALL default to off for new profiles

#### Scenario: Omit toggle reflects persisted value

- **WHEN** the user opens the edit form for a profile with `omitSourceTitle: true`
- **THEN** the toggle SHALL be shown in the on position

#### Scenario: Advanced section auto-expands when omit-source-title is on

- **WHEN** editing a profile that has `omitSourceTitle: true`
- **THEN** the Advanced section SHALL be initially expanded

### Requirement: Database schema includes omit_source_title

The `sync_profiles` table SHALL include an `omit_source_title INTEGER NOT NULL DEFAULT 0` column. Existing rows SHALL be migrated to `omit_source_title = 0`. The database schema version SHALL be bumped to reflect the change.

#### Scenario: New profiles default omit_source_title off

- **WHEN** a new profile is created
- **THEN** the inserted row SHALL have `omit_source_title = 0`

#### Scenario: Existing rows migrated to omit_source_title off

- **WHEN** the database is upgraded from schema v7 to v8
- **THEN** every existing `sync_profiles` row SHALL have `omit_source_title = 0`
- **AND** no other column SHALL be modified by the migration

### Requirement: SHA256 fingerprint is recomputed each sync, not persisted

The SHA256 fingerprint SHALL be computed on demand from the live source event's title during each sync cycle. The fingerprint SHALL NOT be stored in the `sync_mappings` table, the `sync_profiles` table, or any other persistent state. The fingerprint SHALL be regenerated identically on every cycle for the same title input (deterministic).

#### Scenario: Fingerprint is deterministic for same title

- **WHEN** the sync engine computes the fingerprint for source title "Doctor Appointment" in two separate sync cycles
- **THEN** both computations SHALL produce identical hex output

#### Scenario: Fingerprint differs for different titles

- **WHEN** the sync engine computes the fingerprint for source title "Doctor Appointment" in one cycle
- **AND** the fingerprint for source title "Doctor Visit" in another cycle
- **THEN** the two fingerprints SHALL be different

#### Scenario: Fingerprint is not stored in the database

- **WHEN** the sync engine writes a mapping row for a synced event with `omitSourceTitle: true`
- **THEN** no column in `sync_mappings` SHALL contain the SHA256 fingerprint
- **AND** no column in `sync_profiles` SHALL contain the SHA256 fingerprint
- **AND** no column in `sync_created_events` SHALL contain the SHA256 fingerprint
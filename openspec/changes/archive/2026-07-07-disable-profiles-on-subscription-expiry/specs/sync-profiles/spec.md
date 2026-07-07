## MODIFIED Requirements

### Requirement: Enable and disable individual profiles

Each profile SHALL have an independent enabled/disabled toggle. Disabled profiles SHALL be skipped during both manual and background sync. The toggle SHALL be changeable from both the profile config screen and the profile card on the dashboard. An empty event name SHALL NOT cause a profile to be skipped — an empty event name is a valid configuration meaning "use original titles." Additionally, when executing any sync operation, the system SHALL verify that the profile is entitled to sync based on subscription status. Extra profiles (index >= 1) SHALL be skipped for unsubscribed users even if they are marked as enabled.

#### Scenario: Disable a profile from dashboard

- **WHEN** the user toggles a profile card's enabled switch to off
- **THEN** the profile SHALL be persisted as disabled
- **AND** the profile SHALL be skipped in future sync cycles

#### Scenario: Sync all skips disabled profiles

- **WHEN** "Sync All" is triggered and 2 of 3 profiles are disabled
- **THEN** only the 1 enabled profile SHALL execute a sync cycle

#### Scenario: Sync proceeds for profile with empty event name

- **WHEN** a profile has an empty event name, is enabled, and a sync is triggered
- **THEN** the profile SHALL execute a sync cycle normally using source event original titles

#### Scenario: Manual sync skips enabled extra profile when unsubscribed

- **WHEN** the user taps the sync button on a profile at index 1 that is enabled, and the user is not subscribed
- **THEN** the profile SHALL NOT execute a sync cycle despite being enabled
- **AND** no error SHALL be logged for this skipped profile

#### Scenario: Sync All skips enabled extra profiles when unsubscribed

- **WHEN** Sync All is triggered, the user is not subscribed, profile 0 is enabled, and profile 1 is enabled
- **THEN** only profile 0 SHALL execute a sync cycle; profile 1 SHALL be skipped
- **AND** profile 1's skip SHALL NOT produce an error entry in the status table

#### Scenario: Dry Run skips enabled extra profiles when unsubscribed

- **WHEN** a dry run is executed, the user is not subscribed, and profile 1 is enabled
- **THEN** profile 1 SHALL be skipped and SHALL NOT appear in the dry run results

### Requirement: Profile-based Workmanager interval

The system SHALL manage the periodic background task interval based on all enabled AND entitled profiles. The task SHALL use the minimum interval among enabled profiles that are entitled to sync (index 0 when unsubscribed, or all profiles when subscribed). If no profiles are both enabled and entitled to sync, the periodic task SHALL be cancelled.

#### Scenario: Single profile determines interval

- **WHEN** one profile is enabled with interval 30 minutes
- **THEN** the periodic task SHALL be registered with a 30-minute frequency

#### Scenario: Multiple profiles use minimum interval

- **WHEN** two profiles are enabled with intervals 15 minutes and 60 minutes
- **THEN** the periodic task SHALL be registered with a 15-minute frequency

#### Scenario: No enabled profiles cancels task

- **WHEN** all profiles are disabled
- **THEN** the periodic background task SHALL be cancelled

#### Scenario: Interval updates when profiles change

- **WHEN** the set of enabled profiles or their intervals change
- **THEN** the periodic task interval SHALL be updated within 5 seconds to reflect the new minimum

#### Scenario: Unsubscribed extra profiles excluded from interval calculation

- **WHEN** the user is not subscribed, profile 0 has interval 60 minutes, and profile 1 has interval 15 minutes
- **THEN** the periodic task SHALL be registered with a 60-minute frequency (profile 1's interval is ignored)

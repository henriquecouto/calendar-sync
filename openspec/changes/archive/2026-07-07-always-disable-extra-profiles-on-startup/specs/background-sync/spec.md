## MODIFIED Requirements

### Requirement: Periodic fallback sync

The system SHALL maintain a single periodic background task as a safety net. When the task fires, it SHALL first refresh the subscription entitlement from Play Store if more than 24 hours have elapsed since the last check, then iterate over all enabled profiles and run the sync engine for each, provided each profile has the required configuration and permissions. The task interval SHALL be the minimum interval among all enabled AND entitled profiles. When no profiles are enabled and entitled, the periodic task SHALL be cancelled. This catches any changes missed by the ContentObserver.

#### Scenario: Fallback syncs all enabled profiles

- **WHEN** the periodic task fires and 3 profiles are enabled
- **THEN** all 3 profiles SHALL be synced sequentially

#### Scenario: Fallback skips disabled profiles

- **WHEN** the periodic task fires and 1 of 3 profiles is disabled
- **THEN** only the 2 enabled profiles SHALL be synced

#### Scenario: Fallback exits when all profiles disabled

- **WHEN** the periodic fallback task fires and no profiles are enabled
- **THEN** the callback exits immediately without invoking the sync engine

#### Scenario: Fallback skips profile with missing configuration

- **WHEN** the periodic task fires and a profile has no source calendar configured
- **THEN** that profile SHALL be skipped without error and remaining profiles SHALL still be synced

#### Scenario: Fallback skips profile whose calendar was deleted

- **WHEN** the periodic task fires and a profile's source or target calendar no longer exists on the device (account removed, app uninstalled)
- **THEN** that profile SHALL be skipped silently without error
- **AND** the status table SHALL NOT log an error for that profile
- **AND** remaining profiles SHALL still be synced

#### Scenario: Entitlement refreshed on 24-hour TTL before sync

- **WHEN** the periodic task fires and more than 24 hours have elapsed since the last entitlement check
- **THEN** `queryBackgroundEntitlement()` is called before iterating profiles
- **AND** the result is persisted to SharedPreferences
- **AND** the `last_entitlement_check` timestamp is updated

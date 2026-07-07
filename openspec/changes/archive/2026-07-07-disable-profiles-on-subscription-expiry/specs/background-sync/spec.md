## ADDED Requirements

### Requirement: Background sync respects subscription entitlement

The background sync task (both the reactive ContentObserver-triggered path and the periodic fallback) SHALL read the persisted subscription state from SharedPreferences and SHALL skip any profile that is not entitled to sync based on subscription status. The first profile (index 0) SHALL always be synced regardless of subscription state. Extra profiles (index >= 1) SHALL only be synced when `subscription_entitled` is `true`. Skipped profiles SHALL NOT generate error entries in the status table.

#### Scenario: Background reactive sync skips extra profiles when unsubscribed

- **WHEN** the ContentObserver triggers a sync, the persisted `subscription_entitled` is `false`, and there are 3 enabled profiles
- **THEN** only profile at index 0 is synced; profiles at index 1 and 2 are skipped
- **AND** no error entries are logged for the skipped profiles

#### Scenario: Background periodic sync skips extra profiles when unsubscribed

- **WHEN** the periodic fallback task fires, the persisted `subscription_entitled` is `false`, and there are 3 enabled profiles
- **THEN** only profile at index 0 is synced; profiles at index 1 and 2 are skipped
- **AND** no error entries are logged for the skipped profiles

#### Scenario: Background sync runs all profiles when subscribed

- **WHEN** the background task fires, the persisted `subscription_entitled` is `true`, and there are 3 enabled profiles
- **THEN** all 3 profiles are synced

#### Scenario: Background sync runs all profiles on fdroid

- **WHEN** the background task fires on the fdroid flavor and there are 3 enabled profiles
- **THEN** all 3 profiles are synced (fdroid always sets `subscription_entitled` to `true`)

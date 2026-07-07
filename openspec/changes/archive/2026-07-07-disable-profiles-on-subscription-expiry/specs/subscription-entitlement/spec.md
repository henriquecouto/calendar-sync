## ADDED Requirements

### Requirement: Entitlement state is persisted across sessions

The system SHALL persist the `entitled` boolean to SharedPreferences under the key `subscription_entitled` every time it changes. On initialization, the GplaySubscriptionService SHALL restore the persisted value before querying the Play Store, so that `true→false` transitions are correctly detected across cold starts. The fdroid flavor SHALL write `true` on initialization and never change it.

#### Scenario: Cold start after subscription expiry detects transition

- **WHEN** the app cold-starts on gplay, the persisted `subscription_entitled` was `true` from the previous session, and `_querySubscriptionStatus()` finds no active subscription
- **THEN** `entitled` transitions from `true` (restored) to `false` (queried)
- **AND** `onStatusChanged(false)` is called
- **AND** `handleSubscriptionExpired` disables extra profiles in the database

#### Scenario: Cold start with active subscription detects no transition

- **WHEN** the app cold-starts on gplay, the persisted `subscription_entitled` was `true` from the previous session, and `_querySubscriptionStatus()` finds an active subscription
- **THEN** `entitled` stays `true`
- **AND** `onStatusChanged` is NOT called (no transition)
- **AND** profiles remain unchanged

#### Scenario: First gplay launch with no subscription has no transition

- **WHEN** the app launches for the first time on gplay, no persistence key exists, and `_querySubscriptionStatus()` finds no subscription
- **THEN** `entitled` stays `false`
- **AND** `onStatusChanged` is NOT called (no transition)

#### Scenario: First gplay launch with active subscription has transition

- **WHEN** the app launches for the first time on gplay, no persistence key exists, and `_querySubscriptionStatus()` finds an active subscription
- **THEN** `entitled` transitions from `false` (default) to `true`
- **AND** `onStatusChanged(true)` is called
- **AND** `handleSubscriptionRestored` runs

#### Scenario: Fdroid writes true on initialization

- **WHEN** the fdroid flavor initializes
- **THEN** `subscription_entitled` is written as `true` to SharedPreferences

### Requirement: canProfileSync function

The system SHALL provide a `canProfileSync(bool isSubscribed, int profileIndex)` function in the `entitlement.dart` module. It SHALL return `true` when `isSubscribed` is `true` OR `profileIndex` is `0`. It SHALL return `false` only when `isSubscribed` is `false` AND `profileIndex` is greater than `0`. This function is stateless and does not read from any external storage — the caller provides the subscription state.

#### Scenario: First profile allowed when not subscribed

- **WHEN** `canProfileSync(false, 0)` is called
- **THEN** it returns `true`

#### Scenario: Second profile blocked when not subscribed

- **WHEN** `canProfileSync(false, 1)` is called
- **THEN** it returns `false`

#### Scenario: Any profile allowed when subscribed

- **WHEN** `canProfileSync(true, 5)` is called
- **THEN** it returns `true`

#### Scenario: Negative index treated as disallowed

- **WHEN** `canProfileSync(false, -1)` is called
- **THEN** it returns `false` (negative profile index is invalid)

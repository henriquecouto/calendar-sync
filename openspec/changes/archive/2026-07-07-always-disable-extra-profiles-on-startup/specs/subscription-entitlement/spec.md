## MODIFIED Requirements

### Requirement: Entitlement state is persisted across sessions

The system SHALL persist the `entitled` boolean to SharedPreferences under the key `subscription_entitled` every time it changes. On initialization, the GplaySubscriptionService SHALL restore the persisted value before querying the Play Store, so that `true→false` transitions are correctly detected across cold starts. The fdroid flavor SHALL write `true` on initialization and never change it. Additionally, on every app startup when `isSubscribed` is `false`, the system SHALL call `handleSubscriptionExpired` unconditionally — not only on state transition — to ensure extra profiles are disabled regardless of whether the subscription expired in this session or a previous one.

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
- **AND** `handleSubscriptionExpired` runs unconditionally at startup and finds no extra profiles to disable

#### Scenario: First gplay launch with active subscription has transition

- **WHEN** the app launches for the first time on gplay, no persistence key exists, and `_querySubscriptionStatus()` finds an active subscription
- **THEN** `entitled` transitions from `false` (default) to `true`
- **AND** `onStatusChanged(true)` is called
- **AND** `handleSubscriptionRestored` runs

#### Scenario: Fdroid writes true on initialization

- **WHEN** the fdroid flavor initializes
- **THEN** `subscription_entitled` is written as `true` to SharedPreferences

#### Scenario: Subsequent cold start with already-expired subscription disables profiles

- **WHEN** the app cold-starts on gplay, the persisted `subscription_entitled` is already `false` from a previous session, and `_querySubscriptionStatus()` finds no active subscription
- **THEN** no transition occurs (both previous and current are `false`)
- **AND** the unconditional `handleSubscriptionExpired` call at startup disables any extra profiles that are still enabled

## ADDED Requirements

### Requirement: Background entitlement is periodically refreshed from Play Store

The system SHALL provide a per-flavor `queryBackgroundEntitlement()` function. On the gplay flavor, this function SHALL query the Play Store via `queryPastPurchases()` for active subscriptions and fall back to the cached SharedPreferences value on failure. On the fdroid flavor, it SHALL always return `true`. The background sync task SHALL call this function at most once every 24 hours to refresh the cached entitlement state, persisting both the result and the timestamp of the last check.

#### Scenario: Background sync refreshes entitlement after 24 hours

- **WHEN** the background sync task fires on gplay, the last entitlement check was more than 24 hours ago, and `queryPastPurchases()` finds an active subscription
- **THEN** `subscription_entitled` is updated to `true` in SharedPreferences
- **AND** `last_entitlement_check` timestamp is updated
- **AND** all profiles sync normally

#### Scenario: Background sync uses cache within 24-hour window

- **WHEN** the background sync task fires on gplay and the last entitlement check was less than 24 hours ago
- **THEN** no Play Store query is made
- **AND** the cached `subscription_entitled` value is used

#### Scenario: Background sync detects cancelled subscription

- **WHEN** the background sync task fires on gplay, the last entitlement check was more than 24 hours ago, and `queryPastPurchases()` finds NO active subscription
- **THEN** `subscription_entitled` is updated to `false` in SharedPreferences
- **AND** extra profiles (index >= 1) are skipped during sync
- **AND** `last_entitlement_check` timestamp is updated

#### Scenario: Play Store query fails, cache is preserved

- **WHEN** the background sync task fires on gplay, the TTL has expired, but `queryPastPurchases()` throws an error
- **THEN** the cached `subscription_entitled` value is used unchanged
- **AND** `last_entitlement_check` is NOT updated (retry on next sync)
- **AND** sync proceeds with the cached value

#### Scenario: Fdroid always returns true from background query

- **WHEN** `queryBackgroundEntitlement()` is called on the fdroid flavor
- **THEN** it returns `true` without querying any external service

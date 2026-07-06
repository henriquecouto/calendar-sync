# Subscription Entitlement

## Purpose

Provide a runtime mechanism to check whether the user has an active subscription and enforce the freemium model: 1 sync profile free, unlimited profiles with an active subscription. On the gplay flavor, this reflects the actual Play Store subscription state. On the fdroid flavor, the user is always considered entitled (all features unlocked, no profile limits).

## ADDED Requirements

### Requirement: Entitlement check returns subscription status

The system SHALL provide a synchronous `isSubscribed` property on `SubscriptionService` that returns whether the user currently has an active subscription. The value SHALL be cached in memory after initial fetch and refreshed on app start and after purchases.

#### Scenario: Active subscription on gplay returns true

- **WHEN** the gplay flavor detects a valid, non-expired subscription via `queryPastPurchases()`
- **THEN** `isSubscribed` returns `true`

#### Scenario: No subscription on gplay returns false

- **WHEN** the gplay flavor detects no active subscription
- **THEN** `isSubscribed` returns `false`

#### Scenario: Fdroid always returns true

- **WHEN** the fdroid flavor is running
- **THEN** `isSubscribed` ALWAYS returns `true` regardless of any state

### Requirement: Entitlement cache is initialized on app start

The system SHALL query the subscription state asynchronously on app launch and cache the result. Until the initial query completes, `isSubscribed` SHALL return the last known state or a default value.

#### Scenario: Cache is populated on startup

- **WHEN** the app launches on the gplay flavor
- **THEN** `SubscriptionService.initialize()` is called, which queries subscription state and populates the cache

#### Scenario: Cache returns default while loading

- **WHEN** `isSubscribed` is checked before `initialize()` completes on gplay
- **THEN** it returns `false` (conservative default) until the cache is populated

#### Scenario: Fdroid cache returns true immediately

- **WHEN** `initialize()` is called on the fdroid flavor
- **THEN** it completes synchronously with `isSubscribed` set to `true`

### Requirement: Multi-profile creation is blocked for unsubscribed users

The system SHALL allow creating a new profile only when the user is subscribed OR currently has fewer than 1 profile in the database. On the gplay flavor, attempting to create a second profile without an active subscription SHALL show the upsell bottom sheet instead of navigating to the creation screen.

#### Scenario: First profile creation is always allowed

- **WHEN** user has 0 profiles and taps the Create Profile FAB on gplay
- **THEN** the ProfileConfigScreen opens normally regardless of subscription status

#### Scenario: Second profile creation is blocked for unsubscribed user

- **WHEN** user has 1 profile, is NOT subscribed, and taps the Create Profile FAB on gplay
- **THEN** the upsell bottom sheet is displayed and ProfileConfigScreen does NOT open

#### Scenario: Second profile creation is allowed for subscribed user

- **WHEN** user has 1 profile, IS subscribed, and taps the Create Profile FAB on gplay
- **THEN** the ProfileConfigScreen opens normally

#### Scenario: Creating after deleting the only profile is allowed

- **WHEN** user had 1 profile, deleted it, and taps the Create Profile FAB on gplay while not subscribed
- **THEN** the ProfileConfigScreen opens normally (profile count is 0, so the free slot is available)

#### Scenario: Fdroid has no creation limit

- **WHEN** user taps the Create Profile FAB on fdroid
- **THEN** the ProfileConfigScreen opens normally regardless of profile count

### Requirement: Profile enable toggle is blocked for unsubscribed users with multiple profiles

The system SHALL block enabling a profile when the user is not subscribed AND enabling it would result in more than 1 enabled profile. Turning a profile OFF is always allowed.

#### Scenario: Enabling first profile is always allowed

- **WHEN** user has 0 enabled profiles and toggles a profile ON on gplay while not subscribed
- **THEN** the toggle succeeds

#### Scenario: Enabling second profile is blocked for unsubscribed user

- **WHEN** user has 1 enabled profile, is NOT subscribed, and toggles a second profile ON on gplay
- **THEN** the toggle is rejected and the upsell bottom sheet is displayed

#### Scenario: Enabling second profile is allowed for subscribed user

- **WHEN** user has 1 enabled profile, IS subscribed, and toggles a second profile ON on gplay
- **THEN** the toggle succeeds

#### Scenario: Disabling a profile is always allowed

- **WHEN** user toggles any profile OFF on gplay
- **THEN** the toggle succeeds regardless of subscription status

#### Scenario: Fdroid has no toggle restrictions

- **WHEN** user toggles any profile ON or OFF on fdroid
- **THEN** the toggle always succeeds regardless of profile count

### Requirement: Subscription expiration pauses extra profiles

The system SHALL detect when `isSubscribed` transitions from `true` to `false` and SHALL disable all profiles beyond the first one. The enabled state of each profile before expiration SHALL be persisted so it can be restored on re-subscription. The first profile's enabled state SHALL NOT be changed.

#### Scenario: Expiration disables second profile, keeps first

- **WHEN** subscription expires while the user has 3 profiles (all enabled) on gplay
- **THEN** profiles #2 and #3 are set to `enabled = false`, profile #1 retains its enabled state, and the previous enabled states are persisted

#### Scenario: Expiration does not disable the only profile

- **WHEN** subscription expires while the user has 1 profile on gplay
- **THEN** that profile's enabled state is NOT changed

#### Scenario: Fdroid never disables profiles

- **WHEN** running the fdroid flavor
- **THEN** no profile is ever disabled due to subscription expiration

### Requirement: Re-subscription restores previous profile enabled state

The system SHALL detect when `isSubscribed` transitions from `false` to `true` and SHALL re-enable profiles that were active before the previous expiration. Profiles that were already disabled before expiration SHALL NOT be re-enabled.

#### Scenario: Re-subscription restores previously active profiles

- **WHEN** user re-subscribes after an expiration that disabled profiles #2 and #3 on gplay
- **THEN** profiles #2 and #3 are set back to `enabled = true`

#### Scenario: Re-subscription does not restore manually disabled profiles

- **WHEN** user re-subscribes after an expiration, and profile #2 was already `enabled = false` before the expiration occurred
- **THEN** profile #2 remains `enabled = false`

#### Scenario: Fdroid has no restoration logic

- **WHEN** running the fdroid flavor
- **THEN** no profile state restoration occurs

### Requirement: Entitlement refreshes on app resume

The system SHALL refresh the subscription status when the app returns to the foreground, to detect externally changed subscription states (e.g., user cancelled or subscribed via Play Store). If the status changed, the appropriate expiration or restoration logic SHALL execute.

#### Scenario: Subscription cancelled externally triggers expiration

- **WHEN** the app resumes from background and the subscription was cancelled while in background on gplay
- **THEN** `isSubscribed` is updated to `false` and extra profiles are disabled

#### Scenario: New subscription purchased externally triggers restoration

- **WHEN** the app resumes from background and a subscription was purchased via Play Store while in background on gplay
- **THEN** `isSubscribed` is updated to `true` and previously active profiles are re-enabled

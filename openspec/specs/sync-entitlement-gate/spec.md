# Sync Entitlement Gate

## Purpose

Provide defense-in-depth subscription enforcement at the sync execution layer. Before any profile is synced (manually or via background task), the system verifies that the profile is entitled to sync based on subscription status. The first profile (index 0) is always allowed on the free tier; extra profiles require an active subscription. This gate is independent of the database-level `enabled` flag — it catches cases where the primary enforcement mechanism failed.

## Requirements

### Requirement: Sync entitlement gate blocks extra profiles for unsubscribed users

The system SHALL provide a `canProfileSync` function that determines whether a given profile is allowed to execute a sync. A profile at index 0 (the first profile in the ordered list) SHALL always be allowed to sync regardless of subscription status. Profiles at index 1 or higher SHALL only be allowed to sync when the user has an active subscription. This function SHALL be a pure function accepting a boolean `isSubscribed` and an integer `profileIndex`.

#### Scenario: First profile always syncable

- **WHEN** `canProfileSync` is called with `isSubscribed: false` and `profileIndex: 0`
- **THEN** it returns `true`

#### Scenario: Extra profile blocked without subscription

- **WHEN** `canProfileSync` is called with `isSubscribed: false` and `profileIndex: 1`
- **THEN** it returns `false`

#### Scenario: Extra profile allowed with subscription

- **WHEN** `canProfileSync` is called with `isSubscribed: true` and `profileIndex: 2`
- **THEN** it returns `true`

#### Scenario: All profiles allowed when subscribed

- **WHEN** `canProfileSync` is called with `isSubscribed: true` and any `profileIndex`
- **THEN** it returns `true`

### Requirement: Sync execution skips non-entitled profiles

All sync execution paths SHALL check `canProfileSync` before running the sync engine for a given profile. If the check returns `false`, the profile SHALL be skipped silently without error logging. This applies to manual single-profile sync and Sync All. Dry run is intentionally excluded from this gate — it is a read-only preview and SHALL always be allowed regardless of subscription status.

#### Scenario: Manual sync skips extra profile when unsubscribed

- **WHEN** the user taps the sync button on an extra profile (index >= 1) and `isSubscribed` is `false`
- **THEN** the sync does NOT execute and no error is logged

#### Scenario: Manual sync runs for first profile when unsubscribed

- **WHEN** the user taps the sync button on the first profile (index 0) and `isSubscribed` is `false`
- **THEN** the sync executes normally

#### Scenario: Sync All skips extra profiles when unsubscribed

- **WHEN** Sync All is triggered, the user is not subscribed, and there are 3 profiles
- **THEN** only profile at index 0 executes; profiles at index 1 and 2 are skipped

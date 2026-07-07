## Why

When a subscription expires, extra profiles (index >= 1) should be disabled so they stop syncing. The current implementation has two bugs that combine:

**Primary bug**: `GplaySubscriptionService.entitled` is an in-memory field — it always starts as `false` on cold start. When the app restarts after subscription expiry, `_querySubscriptionStatus()` sees `previous: false, current: false` (no transition), so `onStatusChanged` never fires and `handleSubscriptionExpired` never disables the extra profiles in the database. They remain `enabled: true` indefinitely.

**Secondary bug**: Even when `handleSubscriptionExpired` succeeds, the sync execution layer (manual sync, "Sync All", background sync, dry run) has no independent subscription check. Any profile with `enabled: true` in the database will sync, regardless of subscription status.

Together, these mean: subscription expires → user restarts app → extra profiles silently keep syncing forever.

## What Changes

- **Fix the primary bug**: Persist `entitled` to SharedPreferences so the subscription service can detect `true→false` transitions across cold starts. Restore the persisted value on initialization so `_querySubscriptionStatus()` correctly compares against the last known state.
- **Add defense-in-depth**: Introduce a `canProfileSync(profileIndex)` gate at every sync execution path (manual sync, Sync All, background sync, dry run, sync scheduler) that independently verifies subscription status before syncing extra profiles.

## Capabilities

### New Capabilities
- `sync-entitlement-gate`: Subscription-aware gating at the sync execution layer. Before syncing any profile, the system checks whether the profile is allowed to sync based on subscription status. Extra profiles (index >= 1) are skipped for unsubscribed users regardless of their stored `enabled` flag.

### Modified Capabilities
- `subscription-entitlement`: Persist `entitled` to SharedPreferences on every change; restore it on initialization so `true→false` transitions are detected across cold starts. Add a `canProfileSync(profileIndex)` function.
- `sync-profiles`: Sync execution (manual, Sync All, dry run) SHALL skip extra profiles when the user is not subscribed, even if the profile is marked `enabled`
- `background-sync`: Both the periodic fallback task and the reactive ContentObserver-triggered task SHALL skip extra profiles when the user is not subscribed

## Impact

- `lib/subscriptions/gplay_subscription_service.dart` — persist/restore `entitled` to/from SharedPreferences on init and on every status change
- `lib/subscriptions/entitlement.dart` — new `canProfileSync` function and `subscriptionEntitledKey` constant
- `lib/screens/dashboard_screen.dart` — subscription gating on manual sync and Sync All
- `lib/background/sync_task.dart` — subscription gating on background sync (read from SharedPreferences)
- `lib/background/sync_scheduler.dart` — skip extra profiles when computing minimum interval for periodic task registration
- `lib/sync/dry_run_screen.dart` — subscription gating on dry run
- `lib/main.dart` — remove manual SharedPreferences write (now handled inside the subscription service itself)

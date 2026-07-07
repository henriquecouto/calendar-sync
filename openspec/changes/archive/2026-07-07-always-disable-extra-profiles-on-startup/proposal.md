## Why

Two issues cause extra profiles to remain enabled/syncing when the subscription expires:

**Issue 1 — Startup without transition**: `handleSubscriptionExpired` only runs on state transition (`true→false` via `onStatusChanged`). On cold starts where entitled was already `false` (restored from prefs), no transition fires. Extra profiles remain `enabled: true` in the database and appear enabled on the dashboard.

**Issue 2 — Background sync never checks Play Store**: The background sync task reads `subscription_entitled` from SharedPreferences and trusts it indefinitely. If the user cancels the subscription and never opens the app again, the cached value stays `true` forever and extra profiles keep syncing.

## What Changes

- In `main.dart`, after `subscriptionService.initialize()`, call `handleSubscriptionExpired` unconditionally when `!isSubscribed` — not just on transition. Idempotent.
- Add a `queryBackgroundEntitlement()` top-level function to each flavor's `subscription_service.dart` that queries the Play Store (gplay) or returns `true` (fdroid)
- In `sync_task.dart`, check subscription state from Play Store periodically (TTL: 24 hours). On failure, fall back to cached SharedPreferences value
- Persist `last_entitlement_check` timestamp to track when the last Play Store query was made

## Capabilities

### Modified Capabilities
- `subscription-entitlement`: Startup SHALL enforce profile disable when not subscribed, not only on transition. Background tasks SHALL periodically refresh subscription state from Play Store with a 24-hour TTL.
- `background-sync`: The background task SHALL refresh entitlement from Play Store before syncing, on a configurable interval with fallback to cache.

## Impact

- `lib/main.dart` — unconditional `handleSubscriptionExpired` call on startup when `!isSubscribed`
- `lib/subscriptions/subscription_service.dart` (fdroid) — `queryBackgroundEntitlement()` returning `true`
- `lib/subscriptions/subscription_service_gplay.dart` (gplay) — `queryBackgroundEntitlement()` querying Play Store with cache fallback
- `lib/background/sync_task.dart` — TTL-based Play Store query before syncing

## 1. Startup enforcement

- [x] 1.1 In `lib/main.dart`, after `subscriptionService.initialize()`, add unconditional `handleSubscriptionExpired` call when `!subscriptionService.isSubscribed`

## 2. Background entitlement refresh

- [x] 2.1 Add `queryBackgroundEntitlement()` function to `lib/subscriptions/subscription_service.dart` (fdroid — returns `true`)
- [x] 2.2 Add `queryBackgroundEntitlement()` function to `lib/subscriptions/subscription_service_gplay.dart` (gplay — queries Play Store, falls back to cache)
- [x] 2.3 In `lib/background/sync_task.dart`, add TTL-based entitlement refresh: check `last_entitlement_check` timestamp, call `queryBackgroundEntitlement()` if > 24h, persist result and timestamp
- [x] 2.4 Add `const lastEntitlementCheckKey = 'last_entitlement_check'` constant to `lib/subscriptions/entitlement.dart`

## 3. Verification

- [x] 3.1 Run `flutter analyze` and fix any issues
- [x] 3.2 Run `flutter test` and ensure all tests pass

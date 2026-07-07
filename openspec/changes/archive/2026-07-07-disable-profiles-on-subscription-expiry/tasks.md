## 1. Fix primary bug: persist/restore entitled across cold starts

- [x] 1.1 In `GplaySubscriptionService`, add `import 'package:shared_preferences/shared_preferences.dart'`
- [x] 1.2 On `initialize()`, before calling `_querySubscriptionStatus()`, restore `entitled` from `SharedPreferences` key `subscription_entitled` (default `false`)
- [x] 1.3 In `_querySubscriptionStatus()`, write `entitled` to SharedPreferences before calling `onStatusChanged`
- [x] 1.4 In `_onPurchaseUpdate()`, write `entitled` to SharedPreferences when it changes
- [x] 1.5 In `FdroidSubscriptionService.initialize()`, write `entitled: true` to SharedPreferences so the key always exists

## 2. Core entitlement function

- [x] 2.1 Add `canProfileSync(bool isSubscribed, int profileIndex)` function to `lib/subscriptions/entitlement.dart`
- [x] 2.2 Add `const subscriptionEntitledKey = 'subscription_entitled'` constant to `lib/subscriptions/entitlement.dart`

## 3. Gate manual sync paths

- [x] 3.1 Add subscription check to `_syncProfile()` in `lib/screens/dashboard_screen.dart` — skip profile if `!canProfileSync(subscriptionService.isSubscribed, profileIndex)`
- [x] 3.2 Add subscription check to `_syncAll()` in `lib/screens/dashboard_screen.dart` — skip profile if `!canProfileSync(subscriptionService.isSubscribed, profileIndex)`

## 4. Gate dry run

- [x] 4.1 Add subscription check to the dry run loop in `lib/sync/dry_run_screen.dart` — skip extra profiles (index >= 1) when not subscribed

## 5. Gate background sync

- [x] 5.1 In `lib/background/sync_task.dart`, read `subscription_entitled` from SharedPreferences (default `true`) before iterating profiles
- [x] 5.2 Add `canProfileSync` check to the per-profile loop in `callbackDispatcher()`, skipping non-entitled profiles
- [x] 5.3 In `lib/background/sync_scheduler.dart`, read `subscriptionService.isSubscribed` and exclude non-entitled profiles from the min-interval calculation

## 6. Tests

- [x] 6.1 Write unit tests for `canProfileSync` covering: first profile (true), extra profile unsubscribed (false), extra profile subscribed (true), negative index (false)
- [x] 6.2 Write unit tests for `handleSubscriptionExpired` covering: single profile no-op, multiple profiles disables index 1+

## 7. Verification

- [x] 7.1 Run `flutter analyze` and fix any issues
- [x] 7.2 Run `flutter test` and ensure all tests pass

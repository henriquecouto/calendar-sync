## 1. Android-level billing setup (gplay only)

- [x] 1.1 Add `com.android.billingclient:billing` dependency to `build.gradle.kts` inside the `androidComponents.onVariants` block for gplay flavor
- [x] 1.2 Create `android/app/src/gplay/AndroidManifest.xml` declaring `com.android.vending.BILLING` permission
- [x] 1.3 Add `--dart-define=SUBSCRIPTIONS_ENABLED=true` to gplay build commands in `AGENTS.md` and CI workflow

## 2. Dart subscription abstraction layer

- [x] 2.1 Create `lib/subscriptions/subscription_service.dart` with abstract class defining `initialize()`, `getProducts()`, `purchase(productId)`, `restorePurchases()`, `isSubscribed` getter
- [x] 2.2 Create `lib/subscriptions/fdroid_subscription_service.dart` — no-op implementation returning `isSubscribed = true`, empty product list, no-op purchase/restore
- [x] 2.3 Create factory function that reads `bool.fromEnvironment('SUBSCRIPTIONS_ENABLED')` and returns the correct implementation
- [x] 2.4 Wire `SubscriptionService` initialization in `main.dart` so the correct service is instantiated at startup

## 3. Google Play billing implementation

- [x] 3.1 Create `lib/subscriptions/gplay_subscription_service.dart` implementing the abstract interface using `in_app_purchase` package
- [x] 3.2 Implement `initialize()` — set up `InAppPurchase.instance.purchaseStream` listener and call `queryPastPurchases()` to populate cache
- [x] 3.3 Implement `getProducts()` — query Play Store for monthly and yearly subscription product IDs
- [x] 3.4 Implement `purchase(productId)` — launch `InAppPurchase.instance.buyNonConsumable()` or subscription purchase flow
- [x] 3.5 Implement `restorePurchases()` — call `InAppPurchase.instance.restorePurchases()` and update cache from results
- [x] 3.6 Implement app-lifecycle listener to refresh subscription state on resume (`WidgetsBindingObserver`)

## 4. Freemium entitlement logic

- [x] 4.1 Add `canCreateProfile(profileCount)` helper that returns `true` if subscribed OR profile count < 1 (gplay only, always true on fdroid)
- [x] 4.2 Add `canEnableProfile(enabledCount, isTurningOn)` helper that returns `true` if subscribed OR enabled count < 1 OR is turning off
- [x] 4.3 Implement subscription expiration handler: when `isSubscribed` goes `true → false`, persist currently-enabled profile IDs, then disable all profiles beyond the first
- [x] 4.4 Implement subscription restoration handler: when `isSubscribed` goes `false → true`, re-enable profiles that were active before expiration
- [x] 4.5 Wire expiration/restoration checks into the app-resume lifecycle listener

## 5. Entitlement enforcement in UI

- [x] 5.1 Wire `canCreateProfile` check into DashboardScreen FAB `onPressed` — show upsell bottom sheet when blocked
- [x] 5.2 Wire `canEnableProfile` check into DashboardScreen profile toggle `onChanged` — show upsell bottom sheet when blocked, leave toggle OFF
- [x] 5.3 Add `in_app_purchase` dependency to `pubspec.yaml`
- [x] 5.4 Add subscription screen entry point to `DashboardScreen` navigation (gplay only — hide on fdroid)

## 6. Subscription UI screens

- [x] 6.1 Create `lib/screens/subscription_screen.dart` with subscription status display, plan cards with localized prices, subscribe/restore buttons
- [x] 6.2 Display current plan status when subscribed (plan name, renewal info, "Manage" link to Play Store)
- [x] 6.3 Display plan options with localized prices when not subscribed (monthly/yearly cards with subscribe buttons)
- [x] 6.4 Add "Restore Purchases" text link visible when not subscribed
- [x] 6.5 Add loading states for product fetching and purchase processing
- [x] 6.6 Create upsell bottom sheet widget showing the 1-profile limit message, plan prices, subscribe button, and making it dismissible
- [x] 6.7 Style all subscription UI using existing Material You / dynamic_color theme conventions

## 7. Build verification

- [x] 7.1 Run `flutter analyze` and fix any lint issues
- [x] 7.2 Build fdroid APK: `flutter build apk --release` and verify no billing permission in manifest and app launches correctly
- [x] 7.3 Build gplay APK: `flutter build apk --release --flavor gplay --dart-define=SUBSCRIPTIONS_ENABLED=true` and verify billing permission present
- [x] 7.4 Update `.github/workflows/release.yml` to include `--dart-define=SUBSCRIPTIONS_ENABLED=true` on gplay build steps

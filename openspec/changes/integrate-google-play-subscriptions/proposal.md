## Why

The Google Play distribution of the app needs a monetization mechanism via subscriptions. The model is freemium: 1 sync profile free, unlimited profiles with an active subscription. F-Droid users continue with full unrestricted access.

## What Changes

- Add Google Play Billing Library dependency to the `gplay` flavor only (Gradle-level)
- Integrate the `in_app_purchase` Flutter package for cross-platform billing APIs
- Define subscription products (monthly/yearly tiers) in Google Play Console; reference product IDs in code
- Implement billing initialization and purchase flow on the gplay flavor only
- Add a `SubscriptionService` abstraction that enforces the 1-free-profile limit on gplay: blocking creation of a second profile and blocking enabling extra profiles unless subscribed
- When a subscription expires, pause (disable) all profiles beyond the first free one; when re-subscribed, restore their previous enabled state
- Build a subscription management screen (view status, plans with pricing, restore purchases)
- Add an upsell bottom sheet triggered from the "Create Profile" FAB and the profile enable toggle
- Ensure the fdroid flavor compiles and runs with zero billing code or dependencies and no profile limits

## Capabilities

### New Capabilities

- `play-billing-integration`: Google Play Billing Library setup, product definition, purchase flow, and subscription lifecycle management — applicable only to the gplay flavor
- `subscription-entitlement`: Enforces the 1-free-profile limit on gplay; blocks multi-profile creation/enabling for unsubscribed users; pauses extra profiles on expiration; restores state on re-subscription. Fdroid always returns unlimited.
- `subscription-ui`: Subscription management screen showing current plan, pricing, and restore-purchase option; upsell bottom sheet triggered from profile creation and toggle actions. Only visible in gplay flavor.

### Modified Capabilities

None — no existing specs change behavior. The integration is additive and gated by flavor.

## Impact

- **Flutter dependencies**: New `in_app_purchase` package in `pubspec.yaml` (used only by gplay flavor at runtime; fdroid compile-time references are avoided via abstract interfaces)
- **Gradle**: `com.android.billingclient:billing` added conditionally (gplay only) in `android/app/build.gradle.kts`
- **AndroidManifest**: `com.android.vending.BILLING` permission added for gplay flavor only via flavor-specific manifest
- **Dart code**: New `lib/subscriptions/` module with billing service interface, Google Play implementation, and entitlement logic
- **UI**: New subscription screen and upsell bottom sheet; entitlement checks inserted at profile creation FAB and enable toggle on DashboardScreen

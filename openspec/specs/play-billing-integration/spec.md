# Play Billing Integration

## Purpose

Integrate Google Play Billing into the gplay flavor to support subscription products. The fdroid flavor SHALL NOT include any billing code or permissions. Billing Dart dependencies are injected via the pubspec overlay script for gplay builds only.

## Requirements

### Requirement: Billing library is gplay-flavor-only dependency

The system SHALL include the Google Play Billing Library (`com.android.billingclient:billing`) as a Gradle dependency only when building the gplay flavor. The fdroid build SHALL NOT resolve or include this dependency. The system SHALL also ensure that Flutter-level billing packages (`in_app_purchase`, `in_app_purchase_android`, `in_app_purchase_platform_interface`) are resolved only during gplay builds via the `scripts/gplay_build.sh` overlay mechanism, and are absent from the default `pubspec.yaml`.

#### Scenario: Gplay build includes billing library at Gradle and Dart levels

- **WHEN** `scripts/gplay_build.sh "flutter build apk --release --flavor gplay --dart-define=SUBSCRIPTIONS_ENABLED=true"` is executed
- **THEN** the resulting APK includes `com.android.billingclient` classes AND the Dart tree includes `in_app_purchase` bindings

#### Scenario: Fdroid build excludes billing at both levels

- **WHEN** `flutter build apk --release` is executed without `--flavor` and without running the gplay build script
- **THEN** the resulting APK contains zero billing Java classes AND `flutter pub get` never resolved `in_app_purchase` packages

### Requirement: BILLING permission is gplay-flavor-only

The system SHALL declare the `com.android.vending.BILLING` permission in a flavor-specific AndroidManifest (`src/gplay/AndroidManifest.xml`) so that it merges only into the gplay APK. The fdroid APK SHALL NOT request this permission.

#### Scenario: Gplay APK requests BILLING permission

- **WHEN** the gplay APK is inspected (e.g., via `aapt dump permissions`)
- **THEN** `com.android.vending.BILLING` is listed among the requested permissions

#### Scenario: Fdroid APK does not request BILLING permission

- **WHEN** the fdroid APK is inspected
- **THEN** `com.android.vending.BILLING` is NOT listed among the requested permissions

### Requirement: SubscriptionService abstraction

The system SHALL define a `SubscriptionService` abstract class in `lib/subscriptions/` that exposes: product listing, purchase initiation, subscription status check, and purchase restoration. The concrete implementation SHALL be selected at startup based on the `SUBSCRIPTIONS_ENABLED` dart-define flag.

#### Scenario: Gplay flavor uses GplaySubscriptionService

- **WHEN** the app is built with `--dart-define=SUBSCRIPTIONS_ENABLED=true`
- **THEN** `GplaySubscriptionService` is instantiated and wraps `in_app_purchase` APIs

#### Scenario: Fdroid flavor uses FdroidSubscriptionService

- **WHEN** the app is built without `SUBSCRIPTIONS_ENABLED` dart-define
- **THEN** `FdroidSubscriptionService` is instantiated and performs no billing operations

### Requirement: Product definition

The system SHALL define subscription product IDs that match Google Play Console configuration. At minimum, a monthly subscription product ID and a yearly subscription product ID SHALL be referenced in the gplay billing implementation.

#### Scenario: Product list query returns configured products

- **WHEN** `SubscriptionService.getProducts()` is called on the gplay flavor
- **THEN** it returns a list of `ProductDetails` containing at least a monthly and yearly subscription with their localized prices

#### Scenario: Fdroid product list is empty

- **WHEN** `SubscriptionService.getProducts()` is called on the fdroid flavor
- **THEN** it returns an empty list without errors

### Requirement: Purchase flow

The system SHALL allow users to initiate a subscription purchase. On the gplay flavor, this SHALL launch the Google Play billing sheet. On successful purchase, the subscription status SHALL be updated.

#### Scenario: Successful subscription purchase on gplay

- **WHEN** user selects a subscription product and completes the Play billing sheet
- **THEN** the subscription status is cached as active and premium features are unlocked

#### Scenario: Purchase cancellation on gplay

- **WHEN** user initiates a purchase but cancels the billing sheet
- **THEN** the subscription status remains unchanged (not active) and no error is shown

#### Scenario: Purchase attempt on fdroid is no-op

- **WHEN** `SubscriptionService.purchase(productId)` is called on the fdroid flavor
- **THEN** no billing sheet appears and the method returns immediately

### Requirement: Subscription lifecycle — restore purchases

The system SHALL support restoring previously purchased subscriptions via `queryPastPurchases()`. This allows users to recover their subscription after reinstalling the app or switching devices.

#### Scenario: Restore recovers active subscription

- **WHEN** user taps "Restore Purchases" and a valid subscription exists on the Play account
- **THEN** the subscription status is updated to active and premium features are unlocked

#### Scenario: Restore finds no subscription

- **WHEN** user taps "Restore Purchases" and no valid subscription exists
- **THEN** the subscription status remains not active with no error displayed

#### Scenario: Restore on fdroid is no-op

- **WHEN** "Restore Purchases" is triggered on the fdroid flavor
- **THEN** the operation completes immediately with no side effects

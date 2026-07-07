# Subscription UI

## Purpose

Provide user-facing UI for managing the subscription: viewing current plan status, browsing available plans with pricing, initiating purchases, restoring previous purchases, and upsell prompts triggered from the freemium limit. All subscription UI SHALL only be accessible on the gplay flavor.

## Requirements

### Requirement: Subscription management screen

The system SHALL provide a dedicated subscription management screen accessible from the app's main navigation. The screen SHALL display the current subscription status, available plans with prices, and action buttons.

#### Scenario: Screen shows active subscription status

- **WHEN** user opens the subscription screen with an active subscription on gplay
- **THEN** the screen displays the current plan name, renewal date or period, and a "Manage Subscription" option (deep link to Play Store subscription management)

#### Scenario: Screen shows inactive subscription with plan options

- **WHEN** user opens the subscription screen without a subscription on gplay
- **THEN** the screen displays available plans (monthly and yearly) with localized prices and "Subscribe" buttons

#### Scenario: Screen is not accessible on fdroid

- **WHEN** running the fdroid flavor
- **THEN** the subscription screen is NOT shown in navigation and cannot be navigated to

### Requirement: Pricing display

The system SHALL display subscription plan prices using the localized price strings provided by Google Play Billing. Prices SHALL be shown per billing period.

#### Scenario: Monthly plan shows localized monthly price

- **WHEN** the subscription screen loads on gplay
- **THEN** the monthly plan displays its localized price (e.g., "R$ 9,90/mês" or "$4.99/month")

#### Scenario: Yearly plan shows localized yearly price

- **WHEN** the subscription screen loads on gplay
- **THEN** the yearly plan displays its localized price and may also show an equivalent monthly breakdown

### Requirement: Subscribe button triggers purchase flow

The system SHALL wire the "Subscribe" button on each plan to the billing purchase flow. Tapping the button SHALL trigger `SubscriptionService.purchase(productId)`.

#### Scenario: Subscribe button works

- **WHEN** user taps "Subscribe" on the monthly plan on gplay
- **THEN** the Play billing sheet opens for the monthly subscription product

#### Scenario: Loading state during purchase

- **WHEN** the billing sheet is displayed or the purchase is processing
- **THEN** the subscribe button shows a loading indicator and is disabled to prevent double-taps

### Requirement: Restore purchases button

The system SHALL include a "Restore Purchases" button on the subscription screen (gplay only) that calls `SubscriptionService.restorePurchases()`.

#### Scenario: Restore button visible when not subscribed

- **WHEN** user views the subscription screen without an active subscription on gplay
- **THEN** a "Restore Purchases" button or text link is visible

#### Scenario: Restore button triggers restoration

- **WHEN** user taps "Restore Purchases"
- **THEN** the app queries past purchases and updates the subscription status

### Requirement: Subscription screen respects Material You theming

The system SHALL style the subscription screen using the app's existing `dynamic_color` / Material You theme. It SHALL use `FilledButton` for primary actions and follow the existing card-based layout pattern used in DashboardScreen.

#### Scenario: Theme matches rest of app

- **WHEN** the subscription screen is displayed
- **THEN** colors, typography, and component styles match the existing DashboardScreen and Settings patterns

### Requirement: Upsell bottom sheet for freemium limit

The system SHALL display a bottom sheet when a user on the gplay flavor hits the freemium profile limit. The bottom sheet SHALL explain the limit, show subscription plan pricing fetched from Play Billing, and offer a "Subscribe" button. It SHALL be dismissible by swiping down or tapping outside.

#### Scenario: Upsell triggered from Create Profile FAB

- **WHEN** user with 1 profile and no subscription taps the Create Profile FAB on gplay
- **THEN** a bottom sheet appears explaining the 1-profile free limit, displaying plan prices, and offering a Subscribe button

#### Scenario: Upsell triggered from profile enable toggle

- **WHEN** user with 1 enabled profile and no subscription toggles a second profile ON on gplay
- **THEN** a bottom sheet appears explaining the limit and offering subscription

#### Scenario: Upsell bottom sheet is dismissible

- **WHEN** the upsell bottom sheet is displayed
- **THEN** the user can dismiss it by swiping down or tapping outside the sheet

#### Scenario: Successful subscription from upsell enables the action

- **WHEN** user subscribes via the upsell bottom sheet's Subscribe button and the purchase completes
- **THEN** the bottom sheet closes, `isSubscribed` updates to `true`, and the originally blocked action (create profile or enable toggle) proceeds

#### Scenario: Upsell shows localized prices

- **WHEN** the upsell bottom sheet is displayed on gplay
- **THEN** it shows the same localized price strings provided by Play Billing, matching the subscription screen

#### Scenario: Upsell not shown on fdroid

- **WHEN** running the fdroid flavor
- **THEN** the upsell bottom sheet is never displayed, regardless of profile count

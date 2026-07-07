# Play Billing Integration (delta)

## Purpose

Update the existing `play-billing-integration` spec to reflect that billing Dart dependencies are no longer declared in the shared `pubspec.yaml` but are injected via the pubspec overlay script for gplay builds only.

## MODIFIED Requirements

### Requirement: Billing library is gplay-flavor-only dependency

The system SHALL include the Google Play Billing Library (`com.android.billingclient:billing`) as a Gradle dependency only when building the gplay flavor. The fdroid build SHALL NOT resolve or include this dependency. The system SHALL also ensure that Flutter-level billing packages (`in_app_purchase`, `in_app_purchase_android`, `in_app_purchase_platform_interface`) are resolved only during gplay builds via the `scripts/gplay_build.sh` overlay mechanism, and are absent from the default `pubspec.yaml`.

#### Scenario: Gplay build includes billing library at Gradle and Dart levels

- **WHEN** `scripts/gplay_build.sh "flutter build apk --release --flavor gplay --dart-define=SUBSCRIPTIONS_ENABLED=true"` is executed
- **THEN** the resulting APK includes `com.android.billingclient` classes AND the Dart tree includes `in_app_purchase` bindings

#### Scenario: Fdroid build excludes billing at both levels

- **WHEN** `flutter build apk --release` is executed without `--flavor` and without running the gplay build script
- **THEN** the resulting APK contains zero billing Java classes AND `flutter pub get` never resolved `in_app_purchase` packages

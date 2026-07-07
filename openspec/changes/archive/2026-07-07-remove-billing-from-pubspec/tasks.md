## 1. Create overlay file

- [x] 1.1 Remove `in_app_purchase`, `in_app_purchase_android`, `in_app_purchase_platform_interface`, and `url_launcher` from `pubspec.yaml` dependencies
- [x] 1.2 Create `pubspec_gplay.yaml` with the 4 billing + url_launcher dependency lines with correct indentation
- [x] 1.3 Run `flutter pub get` to update `pubspec.lock` (now without billing or url_launcher)

## 2. Create build script

- [x] 2.1 Create `scripts/gplay_build.sh` that: reads overlay, checks for duplicates each dep, appends to pubspec, runs pub get + build, reverts pubspec via trap
- [x] 2.2 `chmod +x scripts/gplay_build.sh`
- [x] 2.3 Test duplicate detection: add a gplay-only dep to pubspec.yaml, run script → must error

## 3. Cleanup now-unnecessary defense mechanisms

- [x] 3.1 Remove `stripBillingPlugin` task from `android/app/build.gradle.kts`
- [x] 3.2 Remove `stripUrlLauncherPlugin` task from `android/app/build.gradle.kts`
- [x] 3.3 Remove `tools:node="remove"` for `com.android.vending.BILLING` from main `AndroidManifest.xml`
- [x] 3.4 Remove `tools:node="remove"` for `ProxyBillingActivity` and `ProxyBillingActivityV2` from main `AndroidManifest.xml`
- [x] 3.5 Remove `billing.properties` exclusion from `androidComponents.onVariants` block
- [x] 3.6 Remove `<queries>` `https` VIEW intent from main `AndroidManifest.xml` (only needed for url_launcher)
- [x] 3.7 Simplify `src/gplay/AndroidManifest.xml`: remove `tools:node="merge"` for billing activities (billing library auto-declares them now)

## 4. Update build commands

- [x] 4.1 Update `AGENTS.md` gplay section to use `scripts/gplay_build.sh`
- [x] 4.2 Update `fastlane/Fastfile` deploy lane to use `scripts/gplay_build.sh`
- [x] 4.3 Update `.github/workflows/release.yml` gplay steps to use the script

## 5. Build verification

- [x] 5.1 Run `flutter analyze` with default pubspec — must pass without billing or url_launcher packages
- [x] 5.2 Build fdroid: `flutter build apk --release --split-per-abi` — must succeed
- [x] 5.3 Build gplay: `scripts/gplay_build.sh "flutter build apk --release --flavor gplay --dart-define=SUBSCRIPTIONS_ENABLED=true --split-per-abi"` — must succeed
- [x] 5.4 Verify fdroid APK has zero billing or url_launcher classes in DEX
- [x] 5.5 Verify gplay APK has billing classes, url_launcher, and BILLING permission

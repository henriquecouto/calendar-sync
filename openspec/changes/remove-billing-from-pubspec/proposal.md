## Why

The fdroid build fails because `in_app_purchase` (and its transitive dependencies `in_app_purchase_android`, `in_app_purchase_platform_interface`) are declared in `pubspec.yaml` for all flavors. F-Droid's build process downloads and attempts to compile `in_app_purchase_android`, which depends on Google Play Services — a non-free, proprietary SDK not available on F-Droid's build infrastructure. The billing code must be completely absent from the pubspec resolution for the fdroid flavor.

## What Changes

- Remove `in_app_purchase`, `in_app_purchase_android`, `in_app_purchase_platform_interface`, and `url_launcher` from `pubspec.yaml`
- Create `pubspec_gplay.yaml` — contains **only** the billing dependencies (not a full pubspec copy)
- Add a build script (`scripts/gplay_build.sh`) that merges billing deps from the overlay into `pubspec.yaml`, detects duplicate declarations (errors if a dep exists in both), builds, and reverts
- Remove now-unnecessary Gradle strip tasks and manifest `tools:node="remove"` entries — the billing native code never enters the fdroid build pipeline at all, so there's nothing to strip
- Update all gplay build commands (AGENTS.md, CI, Fastlane) to use the build script
- Ensure `flutter pub get` on fdroid resolves zero billing packages
- **BREAKING**: gplay builds now require running through `scripts/gplay_build.sh`; direct `flutter build` on the default pubspec won't compile `GplaySubscriptionService`

## Capabilities

### New Capabilities

- `pubspec-overlay`: Lightweight overlay mechanism. `pubspec.yaml` is the single source of truth for shared dependencies. `pubspec_gplay.yaml` is a flat list of extra billing deps only. The build script merges them into pubspec.yaml, errors on duplicates, builds, and reverts.

### Modified Capabilities

- `play-billing-integration`: The Gradle-level conditional billing dependency and strip tasks remain, but the Flutter-level dependency resolution must now be script-driven instead of always present in pubspec.yaml. The spec's requirement "Billing library is gplay-flavor-only dependency" extends to the Dart dependency layer.

## Impact

- **pubspec.yaml**: Drops `in_app_purchase`, `in_app_purchase_android`, `in_app_purchase_platform_interface`, `url_launcher` from dependencies
- **New file**: `pubspec_gplay.yaml` — 4 lines: the gplay-only deps
- **New file**: `scripts/gplay_build.sh` — merges overlay, checks for duplicates, runs pub get + build, reverts on exit
- **Removed from build.gradle.kts**: `stripBillingPlugin` task, `stripUrlLauncherPlugin` task, `billing.properties` exclusion (no longer needed)
- **Removed from AndroidManifest.xml**: `tools:node="remove"` for BILLING permission, ProxyBillingActivity, and `<queries>` https VIEW intent
- **Simplified `src/gplay/AndroidManifest.xml`**: `tools:node="merge"` entries removed (billing library auto-declares)
- **Kept**: gplay Gradle billing dependency, BILLING permission in gplay manifest
- **Dev workflow**: `scripts/gplay_build.sh "flutter run --flavor gplay ..."` for gplay dev; no manual switch/restore needed
- **CI/Fastlane**: Build commands routed through `scripts/gplay_build.sh`

## Context

The current pubspec.yaml declares `in_app_purchase`, `in_app_purchase_android`, and `in_app_purchase_platform_interface` as global dependencies. These are resolved by `flutter pub get` for all builds, including fdroid. F-Droid's build infrastructure cannot resolve `in_app_purchase_android` because its transitive dependency `com.android.billingclient:billing` requires Google Play Services SDK, which is not available on F-Droid's servers. The app must not declare billing dependencies in its main pubspec.

The Gradle-level strip tasks (stripBillingPlugin, stripUrlLauncherPlugin) already handle removing billing native code from the compiled fdroid APK — but they can't run if the build fails at pub resolution time.

## Goals / Non-Goals

**Goals:**
- Remove all billing-related and gplay-only Dart packages from the committed `pubspec.yaml` (including `url_launcher`)
- `pubspec_gplay.yaml` contains **only** the extra billing dependencies (3 lines), not a full pubspec copy — avoids desync with the main file
- A build script merges the overlay into `pubspec.yaml`, validates no duplicate dependencies, builds, and reverts
- `pubspec.yaml` remains the single source of truth for shared dependencies; no manual synchronization needed

**Non-Goals:**
- Per-flavor pubspec.yaml (Flutter doesn't support this)
- Separate Flutter projects or monorepo
- Changing the `bool.fromEnvironment` dart-define mechanism
- Removing Gradle strip tasks (they stay as safety net)

## Decisions

### Decision 1: Overlay file with only billing deps, not a full pubspec copy

**Choice**: `pubspec_gplay.yaml` contains only the dependency lines to inject:
```yaml
  in_app_purchase: ^3.3.0
  in_app_purchase_android: ^0.5.1
  in_app_purchase_platform_interface: ^1.4.1
  url_launcher: ^6.3.0
```

**Rationale**: A full pubspec copy would need manual synchronization every time a shared dependency changes — two sources of truth. A 3-line overlay has zero maintenance burden beyond these three lines. The shared pubspec stays the single authority.

**Alternatives considered**:
- *Full pubspec copy* — causes desync when shared deps change; more maintenance
- *flavors_yaml_merger package* — adds a dev dependency for what is essentially 3 lines

### Decision 2: Merge script with duplicate detection

**Choice**: `scripts/gplay_build.sh`:
1. Reads each dependency line from `pubspec_gplay.yaml`
2. For each, greps `pubspec.yaml` — if found: **error + abort** (duplicate, would create invalid YAML)
3. Appends the billing lines at the end of the `dependencies:` block in `pubspec.yaml`
4. Runs `flutter pub get`
5. Executes the build command passed as argument
6. On exit (success or failure, via `trap`): `git checkout pubspec.yaml`

**Rationale**: Duplicate detection prevents a class of bugs — if someone accidentally declares `in_app_purchase` in the main pubspec, the script fails with a clear message instead of silently producing a pubspec with duplicate keys (which `flutter pub get` would reject). The `trap` ensures the revert always happens, even on build failure or Ctrl+C.

### Decision 3: Single script for both local dev and CI

**Choice**: Same `scripts/gplay_build.sh` used for local development and CI. The script accepts the build command as arguments:

```bash
# Local dev:    scripts/gplay_build.sh flutter run --flavor gplay --dart-define=...
# CI build:     scripts/gplay_build.sh flutter build apk --release --flavor gplay --dart-define=...
```

**Rationale**: One code path, tested everywhere. The developer never needs to remember separate switch/restore steps — the script handles everything.

## Risks / Trade-offs

- **[Risk]** Script killed mid-merge leaves pubspec in dirty state → **Mitigation**: `trap` fires EXIT, SIGINT, SIGTERM; `git checkout pubspec.yaml` always recovers.
- **[Risk]** `pubspec_gplay.yaml` version constraints get stale → **Mitigation**: The 3 lines match the versions already used in the project. When upgrading `in_app_purchase`, update the overlay file too.
- **[Risk]** Shared dependency added with same name as a billing dep → **Mitigation**: The duplicate detection catches this immediately. The error message tells the developer to remove it from pubspec.yaml (it belongs in the overlay only).

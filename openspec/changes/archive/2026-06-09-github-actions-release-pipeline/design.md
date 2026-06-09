## Context

The Calendar Sync app is a Flutter Android project with no existing CI/CD. Releases are done manually: build the APK/AAB locally, create a Git tag, and upload artifacts to a GitHub Release. The `pubspec.yaml` carries the version (`1.0.0+1`) which needs to be reflected in tags and releases. The workflow must run on `ubuntu-latest` (no macOS needed since we target Android only).

## Goals / Non-Goals

**Goals:**
- Trigger on every push to `main` (including merged PRs)
- Build both release APK (universal) and App Bundle (AAB) using Flutter
- Auto-generate a version tag from `pubspec.yaml` version + build number
- Create a GitHub Release with both artifacts attached
- Generate basic release notes (commit log since last tag)

**Non-Goals:**
- Publishing to Google Play Store (requires Play Console integration, out of scope)
- iOS builds (not targeting iOS)
- Signing with production keystore (out of scope — keystore setup is a separate concern)
- Pre-release / beta channels
- Running `flutter test` or `flutter analyze` (can be added later as a separate PR check workflow)

## Decisions

1. **Workflow trigger: `push` to `main`** — simplest approach. Ensures every merged commit produces a release. Alternative considered: `workflow_dispatch` (manual) — rejected because automation is the goal.

2. **Flutter setup: `subosito/flutter-action@v2`** — established community action with caching. No need to manually install Flutter SDK.

3. **Version tag: extracted from `pubspec.yaml`** — read `version:` line, parse into `name` (e.g., `1.0.0`) and optional `build-number` (e.g., `1`), then create tag `v1.0.0+1`. Tag check runs pre-build (fail-fast) to avoid wasting CI minutes. If tag exists on the **same** commit (re-run), skip release gracefully. If tag exists on a **different** commit, fail with actionable message. Alternative considered: derive from git history (semantic-release) — rejected as overkill for a single-developer project; pubspec is the source of truth.

4. **Release notes: `softprops/action-gh-release` with `generate_release_notes: true`** — GitHub-native auto-generated notes (PRs, contributors since last tag). Simple and sufficient.

5. **Artifact retention: default** — GitHub stores release artifacts indefinitely by default. No custom retention policy needed.

## Risks / Trade-offs

- **[Risk] Every push to main creates a release** → Mitigation: If too noisy, can be changed to `workflow_dispatch` or only trigger on PR merge events. Start with the simple approach and iterate.
- **[Risk] Duplicate tags if version not bumped** → Mitigation: Pre-build tag existence check. If tag exists on a different commit, workflow fails early with a clear message. If tag exists on the same commit (re-run), workflow skips release and exits green. Developers must bump the version in `pubspec.yaml` before merging to main.
- **[Risk] Keystore not configured** → Mitigation: Out of scope. The build uses debug keystore by default. Production signing configuration should be a separate change.

## Why

The project currently has no automated release pipeline. Every release APK and App Bundle must be built manually, tagged manually, and a GitHub release created by hand. Automating this ensures consistent, reproducible builds and eliminates manual release toil on every push to main.

## What Changes

- Add a GitHub Actions workflow triggered on pushes to the `main` branch
- Build a release APK (`flutter build apk --release`)
- Build a release App Bundle (`flutter build appbundle --release`)
- Auto-generate a semantic version tag based on the build number
- Create a GitHub Release with both artifacts attached, including auto-generated release notes

## Capabilities

### New Capabilities

- `release-pipeline`: Automated CI/CD pipeline via GitHub Actions that builds release artifacts, tags the commit, and creates a GitHub Release on pushes to main.

### Modified Capabilities

None — no existing specs are affected.

## Impact

- New file: `.github/workflows/release.yml` (GitHub Actions workflow definition)
- No code changes to the Flutter app itself
- Requires `GITHUB_TOKEN` (auto-provided by GitHub Actions) with write permission for releases
- Build environment: `ubuntu-latest` with Flutter SDK setup

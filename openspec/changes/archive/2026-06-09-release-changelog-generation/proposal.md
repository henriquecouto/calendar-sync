## Why

F-Droid changelogs are currently maintained manually — easy to forget. The release pipeline already auto-generates release notes for GitHub Releases. Extending it to also produce a `changelogs/<version-code>.txt` file eliminates manual toil and keeps the F-Droid listing always up to date.

## What Changes

- Modify the `release.yml` workflow to generate a changelog file from git history (commits since last tag)
- Write changelog to `fastlane/metadata/android/en-US/changelogs/<versionCode>.txt` (using the version code from pubspec.yaml)
- Include the changelog file as a GitHub Release asset

## Capabilities

### New Capabilities

None — this is a modification to an existing capability.

### Modified Capabilities

- `release-pipeline`: The workflow SHALL now generate an F-Droid changelog file and include it in the GitHub Release.

## Impact

- Modified file: `.github/workflows/release.yml` (add changelog generation step)
- No changes to Flutter app code
- Changelog format: plain text, one bullet per commit since last tag, prefixed with version header

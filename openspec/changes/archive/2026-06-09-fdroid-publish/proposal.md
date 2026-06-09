## Why

The app currently has no distribution metadata — no store listing, no descriptions, no screenshots. To submit the app to F-Droid (and eventually Google Play), structured metadata is required. Adding this now also gives the GitHub release pipeline richer release notes material.

## What Changes

- Add Fastlane-compatible metadata directory structure (`fastlane/metadata/android/`)
- Provide app title, short description, and full description in `en-US`
- Add placeholder graphics directories for icon, feature graphic, and screenshots
- Ensure `LICENSE` is present and compatible (already GPL-3.0)
- Document F-Droid anti-features (none — no tracking, no proprietary dependencies, no network services)

## Capabilities

### New Capabilities

- `fdroid-metadata`: Structured store listing metadata (title, descriptions, changelogs, graphics) following Fastlane/F-Droid conventions, making the app ready for F-Droid submission.

### Modified Capabilities

None — no existing spec requirements change.

## Impact

- New directory: `fastlane/metadata/android/en-US/` with listing text files
- New directories: `fastlane/metadata/android/en-US/images/` (placeholder until graphics are created)
- No code changes to the Flutter app
- F-Droid build recipe will be submitted separately as an MR to `fdroiddata` (out of scope for this repo)

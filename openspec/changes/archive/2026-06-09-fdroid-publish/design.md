## Context

The app has an existing GitHub release pipeline (APK + AAB builds on push to main), a `LICENSE` file (GPL-3.0), and app ID `dev.henriquecouto.calsync`. There is no store listing metadata. F-Droid uses the Fastlane metadata layout (`fastlane/metadata/android/<locale>/`) as the standard for ingesting app descriptions, changelogs, and graphics. Google Play also supports this same layout, so the work is dual-use.

## Goals / Non-Goals

**Goals:**
- Create Fastlane metadata directory with `en-US` locale
- Provide `title.txt`, `short_description.txt`, `full_description.txt`
- Set up placeholder image directories (`images/`) for future graphics
- Ensure metadata format is compatible with both F-Droid and Google Play
- Validate that the app qualifies for F-Droid (no anti-features triggered by our code)

**Non-Goals:**
- Designing or creating actual graphics (icon, screenshots, feature graphic) — only directory scaffold
- Submitting the merge request to `fdroiddata` (separate process, requires F-Droid GitLab account)
- Google Play Console setup or Play Store publishing
- Automated changelog generation from git history (future enhancement)
- Modifying the Flutter app code or build configuration

## Decisions

1. **Metadata layout: Fastlane standard** — `fastlane/metadata/android/en-US/` with `title.txt`, `short_description.txt` (80 chars max), `full_description.txt`. This layout is consumed by F-Droid, Google Play via fastlane, and other tools. Alternative: a custom `fdroid.txt` or Play Console-only upload — rejected because Fastlane is the ecosystem standard.

2. **Locale: `en-US` only** — single locale for initial release. Additional locales can be added later under sibling directories. No translation infrastructure needed yet.

3. **Graphics: scaffold only** — create `images/` subdirectory with a `.gitkeep` placeholder. Actual screenshots and icons require the app running on a device; these will be created as a follow-up task outside OpenSpec.

4. **Changelogs: manual per-version** — `changelogs/<versionCode>.txt` files. The GitHub release pipeline already auto-generates release notes, but those cover the entire repo. F-Droid changelogs follow a changelog-per-release convention; these will be manually maintained for accuracy. Automation can come later.

5. **Anti-features: document none** — the app uses no tracking, no proprietary dependencies (device_calendar, sqflite, shared_preferences, workmanager are all FOSS), no network services. No anti-features declaration needed.

## Risks / Trade-offs

- **[Risk] Metadata becomes stale if descriptions aren't updated** → Mitigation: Treat metadata as documentation — review and update each release when the app changes.
- **[Risk] Graphics directories empty at submission** → Mitigation: F-Droid accepts submissions without screenshots; they can be added later. Not a blocker.
- **[Risk] Dependencies may contain non-free code** → Mitigation: All current pub dependencies are Apache/MIT/BSD licensed. Verified at time of writing. If new dependencies are added later, they must be vetted for F-Droid compatibility.

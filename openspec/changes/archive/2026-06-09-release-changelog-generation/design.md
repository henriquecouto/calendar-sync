## Context

The release pipeline (`.github/workflows/release.yml`) already builds APK/AAB, creates a Git tag, and publishes a GitHub Release on pushes to `main`. The F-Droid metadata structure (`fastlane/metadata/android/en-US/changelogs/`) exists but changelogs are manually maintained. This change extends the pipeline to auto-generate them.

## Goals / Non-Goals

**Goals:**
- Auto-generate an F-Droid-compatible changelog file during the release workflow
- Write it to `fastlane/metadata/android/en-US/changelogs/<versionCode>.txt`
- Commit the changelog back to the repository so F-Droid picks it up
- Include the changelog file as a GitHub Release asset

**Non-Goals:**
- Automated changelogs for PRs or pre-releases
- Semantic versioning inference (version is read from pubspec.yaml)
- Editing or curating the generated changelog text (manual polish happens after)

## Decisions

1. **Changelog source: `git log` since last tag** — Simple, no external dependencies. Uses `git log --format="- %s" <previous-tag>..HEAD`. If no previous tag exists, uses all commits. Alternative: `generate_release_notes` from GitHub API — rejected because it produces markdown, not plain text suitable for F-Droid.

2. **Auto-commit changelog into repo** — The workflow will commit and push `changelogs/<versionCode>.txt` before creating the tag. This ensures F-Droid always finds the changelog at the expected path. Since the push uses `GITHUB_TOKEN`, it will NOT trigger a recursive workflow run (GitHub Actions built-in guard).

3. **Commit before tag creation** — Changelog is committed first, THEN the tag is created. This way the tag points to the commit that includes the changelog for that version. The final sequence is: build → generate changelog → commit changelog → tag → push all → create release.

4. **Version code extraction from pubspec.yaml** — Parse `version: X.Y.Z+N` and use `N` as the filename (e.g., `1.txt`). This matches the Android `versionCode` convention that F-Droid expects. Using version name (e.g., `1.0.0+1`) was considered but F-Droid's convention is versionCode.

## Risks / Trade-offs

- **[Risk] Changelog duplicates if re-run on same commit** → Mitigation: The existing tag existence guard already handles re-runs (skips if same commit). If the workflow re-runs due to a transient failure after the changelog was pushed but before the tag, the changelog file is idempotent (same content).
- **[Risk] Generated changelog may be too verbose or include irrelevant commits** → Mitigation: This is a single-developer project; the changelog can be manually edited in a follow-up commit if needed. A `.gitlog` exclusion filter could be added later.

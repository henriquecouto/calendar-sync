## 1. Changelog Generation Step

- [x] 1.1 Add step to extract version code (number after `+`) from version string into a separate output
- [x] 1.2 Add step to generate changelog from `git log` since previous tag, write to `fastlane/metadata/android/en-US/changelogs/<versionCode>.txt`
- [x] 1.3 Add step to commit and push the changelog file BEFORE tag creation
- [x] 1.4 Include the changelog file path in the GitHub Release assets list

## 2. Validation

- [x] 2.1 Verify YAML syntax of the updated workflow file
- [x] 2.2 Run `flutter analyze` to confirm no regressions

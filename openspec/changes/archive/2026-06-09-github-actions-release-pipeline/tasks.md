## 1. Workflow Scaffold

- [x] 1.1 Create `.github/workflows/` directory
- [x] 1.2 Create `release.yml` with workflow name, trigger on `push` to `main`, and `ubuntu-latest` runner
- [x] 1.3 Add `contents: write` permission for release creation

## 2. Flutter Build Steps

- [x] 2.1 Add checkout step (`actions/checkout@v4`)
- [x] 2.2 Add Flutter SDK setup step (`subosito/flutter-action@v2`)
- [x] 2.3 Add `flutter pub get` step
- [x] 2.4 Add `flutter build apk --release` step and upload APK as workflow artifact
- [x] 2.5 Add `flutter build appbundle --release` step and upload AAB as workflow artifact

## 3. Tagging

- [x] 3.1 Add step to extract version from `pubspec.yaml`
- [x] 3.2 Add step to create Git tag in `v<version>+<build-number>` format
- [x] 3.3 Add step to push the tag

## 4. GitHub Release

- [x] 4.1 Add step to download both build artifacts
- [x] 4.2 Add step to create GitHub Release with `softprops/action-gh-release@v2`, attaching APK and AAB, with `generate_release_notes: true` and `tag_name` set to the generated tag

## 5. Validation

- [x] 5.1 Run `flutter analyze` locally to ensure no existing issues
- [x] 5.2 Verify YAML syntax of the workflow file
- [x] 5.3 Push to a test branch and verify workflow triggers correctly on push to main (or use `act` for local testing if available)

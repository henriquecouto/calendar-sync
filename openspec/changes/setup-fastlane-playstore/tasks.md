## 1. Build Flavors

- [x] 1.1 Add conditional `gplay` flavor to `android/app/build.gradle.kts` (fdroid is the default non-flavored build, gplay only registered when `--flavor gplay` is passed)
- [x] 1.2 Rename MethodChannel in `lib/calendar/calendar_service.dart` to `calsync/calendar`
- [x] 1.3 Rename MethodChannel in `android/app/src/main/kotlin/dev/henriquecouto/calsync/SoftDeletePlugin.kt` to `calsync/calendar`
- [x] 1.4 Verify `flutter build apk --release` (no `--flavor`) only builds fdroid
- [x] 1.5 Verify `flutter build apk --release --flavor gplay` succeeds
- [x] 1.6 Verify `flutter build appbundle --release --flavor gplay` succeeds

## 2. Fastlane Dependencies

- [x] 2.1 Create `Gemfile` at project root with `fastlane` gem
- [ ] 2.2 Run `bundle install` to generate `Gemfile.lock`
- [ ] 2.3 Verify `bundle exec fastlane --version` works

## 3. Fastlane Configuration

- [x] 3.1 Create `fastlane/Appfile` with gplay package name and JSON key path from env var
- [x] 3.2 Create `fastlane/Fastfile` with `deploy` lane (build gplay AAB + upload via `supply`)
- [x] 3.3 Configure `supply` to use existing metadata at `fastlane/metadata/android/`

## 4. Version Control Hygiene

- [x] 4.1 Add Fastlane temporary files and Play Store credentials to `.gitignore`
- [x] 4.2 ~~Create `.env.example` documenting required environment variables~~ (removed, arquivo desnecessário)
- [x] 4.3 Verify `git status` shows no sensitive files tracked

## 5. CI Integration

- [x] 5.1 Update build steps in `.github/workflows/release.yml` to use flavor flags (fdroid APK + gplay APK + gplay AAB)
- [x] 5.2 Update artifact paths in release step to include both flavor outputs
- [x] 5.3 Add `workflow_dispatch` trigger with `track` input for Play Store upload
- [x] 5.4 Add Ruby setup step (using `ruby/setup-ruby@v1`) in the dispatch job
- [x] 5.5 Add Fastlane upload job that installs gems, writes service account key, and runs `deploy` lane
- [x] 5.6 Copy signing keystore setup in dispatch job so Gradle can sign the AAB

## 6. Verify & Document

- [x] 6.1 Run `flutter analyze` to ensure no regressions
- [x] 6.2 Run `flutter test` to ensure tests pass
- [x] 6.3 Update `AGENTS.md` with flavor and Fastlane release instructions

# App Icon

## Purpose

Define the launcher icon assets for the Android app, including adaptive icons (API 26+), density-specific PNG fallbacks (API 21–25), and monochrome themed icons (API 33+).

## Requirements

### Requirement: Custom launcher icon

The app SHALL display a custom launcher icon on the Android home screen and app drawer, replacing Flutter's default icon. On API 26+ the icon SHALL be an adaptive icon with a VectorDrawable foreground and solid-color background. On API 21–25 the icon SHALL fall back to PNG raster assets.

#### Scenario: Adaptive icon on API 26+ device

- **WHEN** the app is installed on an Android 8.0+ device
- **THEN** the launcher displays the adaptive icon with the calendar-sync VectorDrawable foreground on a blue background

#### Scenario: PNG fallback on API 21 device

- **WHEN** the app is installed on an Android 5.0 device
- **THEN** the launcher displays the PNG icon matching the solid-color VectorDrawable design

### Requirement: Correct density-specific assets

The app SHALL provide `ic_launcher.png` at all 5 standard Android mipmap densities — mdpi (48×48), hdpi (72×72), xhdpi (96×96), xxhdpi (144×144), and xxxhdpi (192×192) — as fallbacks for devices that do not support adaptive icons.

#### Scenario: Icon renders at native resolution on hdpi device (API 23)

- **WHEN** the app is launched on an API 23 hdpi device
- **THEN** the 72×72 `ic_launcher.png` fallback is used and appears sharp

### Requirement: Monochrome themed icon

The app SHALL provide a monochrome VectorDrawable layer for Material You themed icons on API 33+. The monochrome layer SHALL consist of a single silhouette merging the calendar shape and sync arrows, with dot-shaped transparent cutouts.

#### Scenario: Themed icon on API 33+ device

- **WHEN** the user has themed icons enabled on an Android 13+ device
- **THEN** the launcher displays the monochrome silhouette tinted with the system accent color

#### Scenario: No themed icon on API 32 device

- **WHEN** the app is installed on an Android 12 device
- **THEN** the adaptive icon (foreground + background) is displayed without monochrome theming

### Requirement: Source SVG preservation

The source SVG file SHALL be stored in the repository root at `assets/icon.svg` as a design reference. The build process does NOT consume this file directly.

#### Scenario: SVG source is version-controlled

- **WHEN** a developer clones the repository
- **THEN** the SVG source is available at `assets/icon.svg` for visual reference and future redesign

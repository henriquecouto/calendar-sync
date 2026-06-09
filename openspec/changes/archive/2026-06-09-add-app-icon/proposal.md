## Why

The app currently uses Flutter's default launcher icon, which looks generic and unprofessional. A custom icon representing the calendar-sync concept improves brand identity and helps users identify the app on their device.

## What Changes

- Replace the default Flutter launcher icon with a custom adaptive icon (API 26+) using Android VectorDrawables with solid colors
- Add a monochrome layer for Material You themed icons (API 33+)
- Provide PNG fallbacks for devices running API 21–25
- Icon design: blue calendar body with green sync arrows, white interior with light blue dots (no gradients)
- Monochrome silhouette: calendar + sync arrows merged into a single shape with dot cutouts

## Capabilities

### New Capabilities

- `app-icon`: Custom adaptive launcher icon with VectorDrawable foreground, solid-color background, monochrome themed icon layer (API 33+), and PNG fallbacks for older devices

### Modified Capabilities

<!-- None - existing specs unchanged -->

## Impact

- **New files**: `res/drawable/ic_launcher_foreground.xml`, `res/drawable/ic_launcher_monochrome.xml`, `res/mipmap-anydpi-v26/ic_launcher.xml`, `res/mipmap-anydpi-v26/ic_launcher_round.xml`, `res/mipmap-anydpi-v33/ic_launcher_monochrome.xml`
- **Modified files**: `res/mipmap-*/ic_launcher.png` (PNG fallbacks with solid colors)
- **AndroidManifest.xml**: No change needed (still references `@mipmap/ic_launcher` which resolves to adaptive XML on API 26+)
- **Source asset**: `assets/icon.svg` kept as design reference (gradient version preserved, not used at build time)

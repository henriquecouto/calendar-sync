## Context

The app currently has PNG launcher icons at 5 mipmap densities (mdpi through xxxhdpi) generated from an SVG with gradients. The AndroidManifest references `@mipmap/ic_launcher`. We are pivoting to adaptive icons with VectorDrawable to support themed icons (Material You) on Android 13+ while maintaining compatibility back to API 21.

**Constraints:**
- minSdk = 21 (Flutter default). Adaptive icons require API 26. Need PNG fallback for API 21–25.
- Monochrome themed icons require API 33.
- VectorDrawable does not support SVG-style linear gradients with multiple stops. Colors must be solid.
- Solid colors chosen: `#2D6BFF` (calendar background), `#00C98D` (sync arrows), `#FFFFFF` (rings + body), `#DDE7FF` (dots).

## Goals / Non-Goals

**Goals:**
- Provide an adaptive icon (foreground + background) for API 26+
- Provide a monochrome VectorDrawable for Material You themed icons on API 33+
- Provide PNG fallbacks at all 5 densities for API 21–25
- Use solid colors (no gradients) for VectorDrawable compatibility
- Keep `assets/icon.svg` as a visual reference (gradient version, not used at build time)

**Non-Goals:**
- iOS app icon
- Notification or shortcut icons
- Gradients in the icon (incompatible with VectorDrawable + monochrome)

## Decisions

### 1. Adaptive icon approach: VectorDrawable foreground + color background

**Chosen:** `ic_launcher_foreground.xml` as a VectorDrawable, `ic_launcher_background.xml` as a solid color (`#2D6BFF`).
**Alternative:** Both foreground and background as VectorDrawables — unnecessary, background is a flat color.
**Why:** VectorDrawable is Android's native vector format. It scales to any density without raster artifacts and is the only format accepted for monochrome themed icons.

### 2. Monochrome layer: single silhouette with cutouts

**Chosen:** A single path per shape (calendar body + sync arrows merged). The dots become transparent cutouts (path with `fillType="evenOdd"` or explicit subtraction).
**Why:** The monochrome layer must render well when tinted with a single color — the system applies the user's wallpaper accent color. Multiple disjoint filled shapes would all receive the same tint and blend together. Cutouts provide visual distinction.

### 3. File structure

```
res/
├── drawable/
│   ├── ic_launcher_background.xml    ← solid color (#2D6BFF)
│   ├── ic_launcher_foreground.xml    ← VectorDrawable (blue bg + white body + green arrows)
│   └── ic_launcher_monochrome.xml    ← VectorDrawable (single silhouette)
├── mipmap-anydpi-v26/
│   ├── ic_launcher.xml               ← <adaptive-icon> referencing foreground + background
│   └── ic_launcher_round.xml         ← same, for round icon masks
├── mipmap-anydpi-v33/
│   └── ic_launcher_monochrome.xml    ← <adaptive-icon> referencing monochrome drawable
└── mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/
    └── ic_launcher.png               ← PNG fallback (solid colors, no gradient)
```

### 4. PNG fallback generation

**Chosen:** Use ImageMagick `convert` to rasterize the foreground VectorDrawable concept at each density. Colors match the VectorDrawable exactly (no gradients).
**Alternative:** `flutter_launcher_icons` package — adds a dependency and its adaptive icon support is limited.

## Risks / Trade-offs

**[R1] Monochrome legibility at small sizes** → The sync arrows in the silhouette may be too thin at mdpi (48px). Mitigation: scale the arrow strokes proportionally larger in the monochrome drawable.

**[R2] VectorDrawable path complexity** → Converting the SVG design to path data requires precise coordinate translation from the 256×256 SVG viewport to the 108×108 adaptive icon safe zone. Mitigation: use the `viewportWidth`/`viewportHeight` attributes to map coordinates.

**[R3] Adaptive icon safe zone** → Android adaptive icons have a 72×72 safe zone within the 108×108 viewport (the outer 18px on each side may be clipped by the launcher's mask shape). Mitigation: ensure all meaningful content (calendar body, arrows, dots) fits within the inner 72×72 area.

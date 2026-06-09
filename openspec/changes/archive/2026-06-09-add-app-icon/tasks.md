## 1. Background Layer

- [x] 1.1 Create `res/drawable/ic_launcher_background.xml` with solid color `#2D6BFF`

## 2. Foreground VectorDrawable

- [x] 2.1 Create `res/drawable/ic_launcher_foreground.xml` as VectorDrawable (108×108 viewport)
- [x] 2.2 Draw calendar background rect (blue `#2D6BFF`, rounded corners) within safe zone (72×72)
- [x] 2.3 Draw top rings (white `#FFFFFF` rects)
- [x] 2.4 Draw calendar body (white `#FFFFFF` rect)
- [x] 2.5 Draw dots (light blue `#DDE7FF` circles)
- [x] 2.6 Draw sync arrows (green `#00C98D` paths, stroke only)

## 3. Adaptive Icon Definition (API 26+)

- [x] 3.1 Create `res/mipmap-anydpi-v26/ic_launcher.xml` referencing foreground + background
- [x] 3.2 Create `res/mipmap-anydpi-v26/ic_launcher_round.xml` (same content)

## 4. Monochrome Layer (API 33+)

- [x] 4.1 Create `res/drawable/ic_launcher_monochrome.xml` as VectorDrawable (single silhouette)
- [x] 4.2 Calendar body + sync arrows merged into filled paths
- [x] 4.3 Dots as transparent cutouts (evenOdd fill or path subtraction)
- [x] 4.4 Create `res/mipmap-anydpi-v33/ic_launcher_monochrome.xml` referencing monochrome drawable

## 5. PNG Fallbacks (API 21–25)

- [x] 5.1 Generate mdpi (48×48) PNG from foreground VectorDrawable concept
- [x] 5.2 Generate hdpi (72×72) PNG
- [x] 5.3 Generate xhdpi (96×96) PNG
- [x] 5.4 Generate xxhdpi (144×144) PNG
- [x] 5.5 Generate xxxhdpi (192×192) PNG
- [x] 5.6 Replace `res/mipmap-*/ic_launcher.png` with solid-color PNGs

## 6. Verification

- [x] 6.1 Run `flutter analyze` to confirm no project-level issues
- [x] 6.2 Run `flutter build apk --debug` to confirm the APK builds with adaptive icon
- [x] 6.3 Verify `mipmap-anydpi-v26/` takes precedence over raster mipmaps in the built APK

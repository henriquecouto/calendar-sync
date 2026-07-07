#!/bin/bash
set -euo pipefail

OVERLAY="pubspec_gplay.yaml"

GPLAY_FILES=(
    "lib/subscriptions/subscription_service_gplay.dart:lib/subscriptions/subscription_service.dart"
    "lib/screens/subscription_screen_gplay.dart:lib/screens/subscription_screen.dart"
    "lib/screens/upsell_bottom_sheet_gplay.dart:lib/screens/upsell_bottom_sheet.dart"
)

BACKUP_DIR="$(mktemp -d)"

cleanup() {
    echo "[gplay_build] Restoring files..."
    for pair in "${GPLAY_FILES[@]}"; do
        target="${pair##*:}"
        backup="$BACKUP_DIR/$(basename "$target")"
        if [ -f "$backup" ]; then
            cp "$backup" "$target"
        fi
    done
    if [ -f "$BACKUP_DIR/pubspec.yaml" ]; then
        cp "$BACKUP_DIR/pubspec.yaml" pubspec.yaml
    fi
    if [ -f "$BACKUP_DIR/pubspec.lock" ]; then
        cp "$BACKUP_DIR/pubspec.lock" pubspec.lock
    fi
    if [ -f "$BACKUP_DIR/analysis_options.yaml" ]; then
        cp "$BACKUP_DIR/analysis_options.yaml" analysis_options.yaml
    fi
    rm -rf "$BACKUP_DIR"
}
trap cleanup EXIT INT TERM

if [ ! -f "$OVERLAY" ]; then
    echo "ERROR: $OVERLAY not found" >&2
    exit 1
fi

cp pubspec.yaml "$BACKUP_DIR/pubspec.yaml"
cp pubspec.lock "$BACKUP_DIR/pubspec.lock"
cp analysis_options.yaml "$BACKUP_DIR/analysis_options.yaml"

for pair in "${GPLAY_FILES[@]}"; do
    source_file="${pair%%:*}"
    target="${pair##*:}"
    if [ -f "$target" ]; then
        cp "$target" "$BACKUP_DIR/$(basename "$target")"
    fi
    cp "$source_file" "$target"
done

while IFS= read -r line; do
    if [ -z "$line" ]; then continue; fi
    dep_name=$(echo "$line" | sed 's/^\s*//;s/:.*//')
    if grep -q "$dep_name:" pubspec.yaml; then
        echo "ERROR: '$dep_name' already declared in pubspec.yaml. Remove it — it belongs in $OVERLAY." >&2
        exit 1
    fi
    sed -i "/^dependencies:/a\\$line" pubspec.yaml
done < "$OVERLAY"

echo "[gplay_build] Overlay applied. Running flutter pub get..."
flutter pub get

build_cmd="${*:-flutter build apk --release --flavor gplay --dart-define=SUBSCRIPTIONS_ENABLED=true}"
echo "[gplay_build] Building: $build_cmd"
eval "$build_cmd"

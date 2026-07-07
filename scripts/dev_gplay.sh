#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

OVERLAY="pubspec_gplay.yaml"

GPLAY_FILES=(
    "lib/subscriptions/subscription_service_gplay.dart:lib/subscriptions/subscription_service.dart"
    "lib/screens/subscription_screen_gplay.dart:lib/screens/subscription_screen.dart"
    "lib/screens/upsell_bottom_sheet_gplay.dart:lib/screens/upsell_bottom_sheet.dart"
)

if [ ! -f "$OVERLAY" ]; then
    echo "ERROR: $OVERLAY not found" >&2
    exit 1
fi

for pair in "${GPLAY_FILES[@]}"; do
    source_file="${pair%%:*}"
    target="${pair##*:}"
    cp "$source_file" "$target"
done

while IFS= read -r line; do
    if [ -z "$line" ]; then continue; fi
    dep_name=$(echo "$line" | sed 's/^\s*//;s/:.*//')
    if grep -q "$dep_name:" pubspec.yaml; then
        echo "Already in gplay mode. Run scripts/dev_fdroid.sh to revert." >&2
        exit 1
    fi
    sed -i "/^dependencies:/a\\$line" pubspec.yaml
done < "$OVERLAY"

flutter pub get

echo "Switched to gplay dev mode. Zed/IDE debug will work now."
echo "Run 'scripts/dev_fdroid.sh' to revert before committing."

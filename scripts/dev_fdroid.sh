#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

git checkout pubspec.yaml pubspec.lock analysis_options.yaml \
    lib/subscriptions/subscription_service.dart \
    lib/screens/subscription_screen.dart \
    lib/screens/upsell_bottom_sheet.dart 2>/dev/null

flutter pub get

echo "Reverted to fdroid dev mode."

#!/bin/bash
set -euo pipefail

FLAVOR="${1:-}"

if [ "$FLAVOR" != "fdroid" ] && [ "$FLAVOR" != "gplay" ]; then
    echo "Usage: $0 <fdroid|gplay> [build command...]" >&2
    echo "  fdroid: flutter run --debug" >&2
    echo "  gplay: flutter run --debug --flavor gplay --dart-define=SUBSCRIPTIONS_ENABLED=true" >&2
    exit 1
fi

shift
if [ "$FLAVOR" = "gplay" ]; then
    scripts/gplay_build.sh "${@:-flutter run --debug --flavor gplay --dart-define=SUBSCRIPTIONS_ENABLED=true}"
else
    eval "${@:-flutter run --debug}"
fi

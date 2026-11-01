#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo 'Flutter SDK is required.' >&2
  exit 1
fi

flutter pub get
flutter analyze --no-fatal-infos
flutter test

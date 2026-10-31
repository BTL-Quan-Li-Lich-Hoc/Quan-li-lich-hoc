#!/usr/bin/env bash
set -euo pipefail

dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-fatal-infos
flutter test

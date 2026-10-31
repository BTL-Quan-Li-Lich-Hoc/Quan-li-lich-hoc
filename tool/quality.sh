#!/usr/bin/env bash
set -euo pipefail

dart format lib test
flutter analyze --no-fatal-infos
flutter test

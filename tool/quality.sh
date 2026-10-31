#!/usr/bin/env bash
set -euo pipefail

printf '\n== Format ==\n'
dart format lib test

printf '\n== Analyze ==\n'
flutter analyze

printf '\n== Test ==\n'
flutter test

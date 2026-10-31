#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="/workspaces/Quan-li-lich-hoc"

printf '\n== Better Phenikaa Schedule: setup ==\n'

git config --global --add safe.directory "${WORKSPACE}" || true
flutter config --no-analytics
dart --disable-analytics
bash tool/bootstrap.sh

dart format lib test
flutter analyze
flutter test

printf '\nSetup complete.\n'

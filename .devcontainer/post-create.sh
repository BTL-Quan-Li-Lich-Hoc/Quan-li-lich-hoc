#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="/workspaces/Quan-li-lich-hoc"

printf '\n== Better Phenikaa Schedule: container bootstrap ==\n'

git config --global --add safe.directory "${WORKSPACE}" || true
flutter config --no-analytics
dart --disable-analytics
bash tool/bootstrap.sh

printf '\nReady. Useful commands:\n'
printf '  bash tool/setup.sh\n'
printf '  bash tool/quality.sh\n'
printf '  flutter run\n'
printf '  flutter run -d web-server --web-port 3000 --web-hostname 0.0.0.0\n'

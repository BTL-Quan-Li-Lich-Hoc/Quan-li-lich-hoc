#!/usr/bin/env bash
set -euo pipefail

printf '\n== Better Phenikaa Schedule: container bootstrap ==\n'
flutter config --no-analytics
bash tool/bootstrap.sh

printf '\nReady. Useful commands:\n'
printf '  bash tool/quality.sh\n'
printf '  flutter run\n'
printf '  flutter run -d web-server --web-port 3000 --web-hostname 0.0.0.0\n'

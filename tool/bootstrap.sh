#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo 'Flutter not found. Use the Dev Container or install Flutter 3.47.2.' >&2
  exit 1
fi

required_flutter='3.47.2'
current_flutter="$(flutter --version | head -n 1 | awk '{print $2}')"
if [[ "${current_flutter}" != "${required_flutter}" ]]; then
  echo "Expected Flutter ${required_flutter}, found ${current_flutter}." >&2
  exit 1
fi

if [[ ! -d android || ! -d web ]]; then
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' EXIT

  flutter create \
    --platforms=android,web \
    --org vn.edu.phenikaa \
    --project-name better_phenikaa_schedule \
    "${tmp_dir}/scaffold"

  if [[ ! -d android ]]; then
    cp -R "${tmp_dir}/scaffold/android" ./android
  fi

  if [[ ! -d web ]]; then
    cp -R "${tmp_dir}/scaffold/web" ./web
  fi

  if [[ ! -f .metadata ]]; then
    cp "${tmp_dir}/scaffold/.metadata" ./.metadata
  fi
fi

flutter pub get

# Compatibility workaround used in the independently buildable Nhom10 repo.
# flutter_inappwebview_android 1.1.3 references a legacy ProGuard configuration
# rejected by modern Android Gradle Plugin versions. Patch only the disposable
# PUB_CACHE on this test runner; no third-party source is committed.
inappwebview_gradle="${PUB_CACHE:-${HOME}/.pub-cache}/hosted/pub.dev/flutter_inappwebview_android-1.1.3/android/build.gradle"
if [[ -f "${inappwebview_gradle}" ]] && grep -q "getDefaultProguardFile('proguard-android.txt')" "${inappwebview_gradle}"; then
  sed -i "s/getDefaultProguardFile('proguard-android.txt')/getDefaultProguardFile('proguard-android-optimize.txt')/g" "${inappwebview_gradle}"
  echo 'Patched flutter_inappwebview_android release ProGuard compatibility.'
fi

echo 'Bootstrap complete.'

#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="${root_dir}/platform/android_widget/app/src/main"
target_dir="${root_dir}/android/app/src/main"

if [[ ! -d "${root_dir}/android" ]]; then
  echo 'Android scaffold is missing. Run tool/bootstrap.sh first.' >&2
  exit 1
fi

mkdir -p \
  "${target_dir}/kotlin/vn/edu/phenikaa/better_phenikaa_schedule" \
  "${target_dir}/res/layout" \
  "${target_dir}/res/xml" \
  "${target_dir}/res/drawable" \
  "${target_dir}/res/values"

cp "${source_dir}/AndroidManifest.xml" "${target_dir}/AndroidManifest.xml"
cp "${source_dir}/kotlin/vn/edu/phenikaa/better_phenikaa_schedule/"*.kt \
  "${target_dir}/kotlin/vn/edu/phenikaa/better_phenikaa_schedule/"
cp "${source_dir}/res/layout/"*.xml "${target_dir}/res/layout/"
cp "${source_dir}/res/xml/"*.xml "${target_dir}/res/xml/"
cp "${source_dir}/res/drawable/"*.xml "${target_dir}/res/drawable/"
cp "${source_dir}/res/values/strings.xml" "${target_dir}/res/values/strings.xml"

echo 'Android home widget sources installed.'

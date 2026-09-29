#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app="${1:-dist/KLAP.app}"
actool="${KLAP_ACTOOL:-/Applications/Xcode.app/Contents/Developer/usr/bin/actool}"
if [[ ! -x "$actool" ]]; then
    echo "Icon Composer 아이콘 빌드에는 Xcode의 actool이 필요합니다." >&2
    exit 1
fi
mkdir -p .build/icon-output "$app/Contents/Resources"
"$actool" KLAP.icon --compile .build/icon-output --platform macosx \
    --minimum-deployment-target 13.0 --app-icon KLAP \
    --output-partial-info-plist .build/icon-info.plist
cp .build/icon-output/Assets.car .build/icon-output/KLAP.icns "$app/Contents/Resources"/

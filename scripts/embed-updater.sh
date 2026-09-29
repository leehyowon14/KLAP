#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app="${1:-dist/KLAP.app}"
framework=".build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
[[ -d "$framework" ]] || { echo "Sparkle을 먼저 swift build로 준비해 주세요." >&2; exit 1; }
mkdir -p "$app/Contents/Frameworks"
# ditto preserves Sparkle's symlinks, helper permissions and upstream signatures.
ditto "$framework" "$app/Contents/Frameworks/Sparkle.framework"
codesign --verify --deep --strict "$app/Contents/Frameworks/Sparkle.framework"

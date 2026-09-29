#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Library/Developer/CommandLineTools}"
swift build --build-system native -c release --product KLAP
output="$(mktemp -d "${TMPDIR:-/tmp/}klap-updater-check.XXXXXX")"
trap 'rm -rf "$output"' EXIT
app="$output/KLAPUpdaterChecks.app"
mkdir -p "$app/Contents/MacOS"
cp Resources/Info.plist "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier dev.leehyowon.klap.updaterchecks' "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable UpdaterChecks' "$app/Contents/Info.plist"
framework=".build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64"
swiftc -swift-version 5 -F "$framework" -framework Sparkle -Xlinker -rpath -Xlinker @executable_path/../Frameworks Sources/KLAP/AppUpdater.swift Tests/KLAPUpdaterChecks/main.swift -o "$app/Contents/MacOS/UpdaterChecks"
bash scripts/embed-updater.sh "$app"
codesign --force --sign - "$app"
"$app/Contents/MacOS/UpdaterChecks"

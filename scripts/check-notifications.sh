#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Library/Developer/CommandLineTools}"
swift build --build-system native -c release --product KLAP
output="$(mktemp -d "${TMPDIR:-/tmp/}klap-notification-check.XXXXXX")"
trap 'rm -rf "$output"' EXIT
app="$output/KLAPNotificationChecks.app"
mkdir -p "$app/Contents/MacOS"
cp Resources/Info.plist "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier dev.leehyowon.klap.notificationchecks' "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable NotificationChecks' "$app/Contents/Info.plist"
swiftc -swift-version 5 -I .build/arm64-apple-macosx/release/Modules Sources/KLAP/ContentNotificationService.swift .build/arm64-apple-macosx/release/KLAPCore.build/*.o Tests/KLAPNotificationChecks/main.swift -o "$app/Contents/MacOS/NotificationChecks"
codesign --force --sign - "$app"
"$app/Contents/MacOS/NotificationChecks"

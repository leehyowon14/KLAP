#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Library/Developer/CommandLineTools}"
swift build --build-system native -c release --product KLAP
bin="$(swift build --build-system native -c release --show-bin-path)"
output="$(mktemp -d "${TMPDIR:-/tmp/}klap-study-check.XXXXXX")"
trap 'rm -rf "$output"' EXIT
app="$output/KLAPStudyChecks.app"
mkdir -p "$app/Contents/MacOS"
cp Resources/Info.plist "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier dev.leehyowon.klap.studychecks.$RANDOM" "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable StudyChecks' "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :KLAPDevelopmentBuild bool true' "$app/Contents/Info.plist"
sources=()
for source in Sources/KLAP/*.swift; do
    [[ "$source" == Sources/KLAP/main.swift ]] || sources+=("$source")
done
swiftc -swift-version 5 -I "$bin/Modules" -F "$bin" -framework Sparkle \
    -Xlinker -rpath -Xlinker "$bin" "${sources[@]}" \
    "$bin"/KLAPCore.build/*.o Tests/KLAPStudyChecks/main.swift -o "$app/Contents/MacOS/StudyChecks"
codesign --force --sign - "$app"
"$app/Contents/MacOS/StudyChecks"

#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
root="$PWD"
app="${1:-$root/dist/KLAP.app}"
[[ "$app" = /* ]] || app="$root/$app"
source_repo="${KLAP_CORE_SOURCE:-${KLAP_CLI_SOURCE:-$root/../KLAP_cli}}"
ref="$(cat Bridge/core-ref)"
staging="$root/.build/cli-$ref"
mkdir -p "$staging" "$app/Contents/MacOS" "$app/Contents/Resources"
if [ ! -f "$staging/go.mod" ]; then
  git -C "$source_repo" archive "$ref" | tar -x -C "$staging"
fi
(cd "$staging" && go test ./cmd/klap-core && go build -o "$app/Contents/MacOS/KLAPBridge" ./cmd/klap-core)
for product in ReminderBridge CalendarBridge TranscriptBridge; do
  swift build --build-system native --package-path "$staging/bridges/macos" -c release --product "$product"
  cp "$staging/bridges/macos/.build/release/$product" "$app/Contents/MacOS/$product"
  codesign --force --sign - "$app/Contents/MacOS/$product"
done
codesign --force --sign - "$app/Contents/MacOS/KLAPBridge"
cp "$staging/LICENSE" "$app/Contents/Resources/KLAP-CLI-LICENSE"

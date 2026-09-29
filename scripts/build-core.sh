#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
root="$PWD"
app="${1:-$root/dist/KLAP.app}"
[[ "$app" = /* ]] || app="$root/$app"
source_repo="${KLAP_CLI_SOURCE:-$root/../KLAP_cli}"
ref="$(cat Bridge/core-ref)"
staging="$root/.build/cli-$ref"
mkdir -p "$staging" "$app/Contents/MacOS"
if [ ! -f "$staging/go.mod" ]; then
  git -C "$source_repo" archive "$ref" | tar -x -C "$staging"
fi
for patch_file in "$root"/Bridge/patches/*.patch; do
  if git -C "$staging" apply --check "$patch_file" 2>/dev/null; then
    git -C "$staging" apply "$patch_file"
  else
    git -C "$staging" apply --reverse --check "$patch_file"
  fi
done
mkdir -p "$staging/cmd/klap-mac-bridge"
cp Bridge/*.go "$staging/cmd/klap-mac-bridge/"
(cd "$staging" && go test ./cmd/klap-mac-bridge && go build -o "$app/Contents/MacOS/KLAPBridge" ./cmd/klap-mac-bridge)
for product in ReminderBridge CalendarBridge; do
  swift build --build-system native --package-path "$staging/bridges/macos" -c release --product "$product"
  cp "$staging/bridges/macos/.build/release/$product" "$app/Contents/MacOS/$product"
  codesign --force --sign - "$app/Contents/MacOS/$product"
done
codesign --force --sign - "$app/Contents/MacOS/KLAPBridge"
cp "$staging/LICENSE" "$app/Contents/Resources/KLAP-CLI-LICENSE"

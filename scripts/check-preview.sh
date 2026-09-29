#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Library/Developer/CommandLineTools}"
swift build --build-system native -c release --product KLAP
output="$(mktemp -d "${TMPDIR:-/tmp/}klap-preview-check.XXXXXX")"
trap 'rm -rf "$output"' EXIT
swiftc -swift-version 5 -I .build/arm64-apple-macosx/release/Modules Sources/KLAP/AttachmentManager.swift .build/arm64-apple-macosx/release/KLAPCore.build/*.o Tests/KLAPPreviewChecks/main.swift -o "$output/PreviewChecks"
"$output/PreviewChecks"

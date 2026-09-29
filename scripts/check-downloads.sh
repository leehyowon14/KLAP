#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
output="$(mktemp -d "${TMPDIR:-/tmp/}klap-download-check.XXXXXX")"
trap 'rm -rf "$output"' EXIT
swiftc Sources/KLAP/LectureDownloadLocation.swift Sources/KLAP/LectureDownloadState.swift Tests/KLAPDownloadChecks/main.swift -o "$output/check"
"$output/check"

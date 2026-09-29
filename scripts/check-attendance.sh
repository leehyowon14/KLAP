#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
output="$(mktemp -d "${TMPDIR:-/tmp/}klap-attendance-check.XXXXXX")"
trap 'rm -rf "$output"' EXIT
swiftc Sources/KLAP/AttendanceModels.swift Tests/KLAPAttendanceChecks/main.swift -o "$output/check"
"$output/check"

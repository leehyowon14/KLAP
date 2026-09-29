#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Library/Developer/CommandLineTools}"
output="$(mktemp -d "${TMPDIR:-/tmp/}klap-permission-check.XXXXXX")"
trap 'rm -rf "$output"' EXIT
swiftc Sources/KLAP/EventPermission.swift Tests/KLAPEventPermissionChecks/main.swift -o "$output/check"
"$output/check"

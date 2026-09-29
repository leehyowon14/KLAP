#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Library/Developer/CommandLineTools}"
output="$(mktemp -d "${TMPDIR:-/tmp/}klap-login-check.XXXXXX")"
trap 'rm -rf "$output"' EXIT
swiftc -swift-version 5 Sources/KLAP/LoginItemController.swift Sources/KLAP/LoginLaunch.swift Tests/KLAPLoginItemChecks/main.swift -o "$output/LoginChecks"
"$output/LoginChecks"

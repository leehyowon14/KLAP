#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Library/Developer/CommandLineTools}"
output="$(mktemp -d "${TMPDIR:-/tmp/}klap-installation-check.XXXXXX")"
trap 'rm -rf "$output"' EXIT
swiftc -swift-version 5 Sources/KLAP/InstallationNotice.swift Tests/KLAPInstallationChecks/main.swift -o "$output/check"
"$output/check"

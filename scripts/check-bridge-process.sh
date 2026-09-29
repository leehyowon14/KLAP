#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Library/Developer/CommandLineTools}"
output="$(mktemp -d "${TMPDIR:-/tmp/}klap-bridge-process-check.XXXXXX")"
trap 'rm -rf "$output"' EXIT
swiftc -swift-version 5 Sources/KLAP/BridgeClient.swift Sources/KLAP/BridgeProtocol.swift Tests/KLAPBridgeProcessChecks/main.swift -o "$output/check"
"$output/check"

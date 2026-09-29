#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
output="$(mktemp -d "${TMPDIR:-/tmp/}klap-academic-check.XXXXXX")"
trap 'rm -rf "$output"' EXIT
swiftc Sources/KLAP/AcademicModels.swift Tests/KLAPAcademicChecks/main.swift -o "$output/check"
"$output/check"

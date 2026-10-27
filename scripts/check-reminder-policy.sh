#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
core_ref="$(cat Bridge/core-ref)"
swift test --package-path ".build/cli-$core_ref/bridges/macos" --filter ReminderPolicyTests

#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build --build-system native -c release --product KLAP
mkdir -p dist/KLAP.app/Contents/MacOS dist/KLAP.app/Contents/Resources
cp .build/release/KLAP dist/KLAP.app/Contents/MacOS/KLAP
cp Resources/Info.plist dist/KLAP.app/Contents/Info.plist
bash scripts/build-core.sh
codesign --force --sign - dist/KLAP.app
echo "Built: $PWD/dist/KLAP.app"

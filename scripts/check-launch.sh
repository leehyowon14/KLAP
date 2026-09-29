#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app="${1:-dist/KLAP-Dev.app}"
executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app/Contents/Info.plist")
python3 - "$PWD/$app/Contents/MacOS/$executable" "$PWD/$app" <<'PY'
import json, pathlib, subprocess, sys, tempfile
required = {'initialized', 'delegateRetained', 'modelDeferredUntilLaunch', 'accessory', 'statusVisible', 'iconPresent', 'statusHasWidth', 'panelAnchored', 'firstClickOpened', 'panelOpened', 'reopenOpened', 'panelClosed', 'detailIconClosed', 'detailOutsideClosed', 'inactiveIconClosed', 'repeatedToggle'}
def check(raw):
    values = json.loads(raw)
    if set(values) != required or not all(values.values()):
        raise SystemExit(f'Startup checks failed: {values}')
# This starts the real optimized app, but disables account/network/sync work.
result = subprocess.run([sys.argv[1], '--smoke-test'], capture_output=True, text=True, timeout=15)
if result.returncode:
    raise SystemExit(f'Startup failed: {result.stdout} {result.stderr}')
check(result.stdout)
with tempfile.TemporaryDirectory(prefix='klap-launch-') as directory:
    output=pathlib.Path(directory)/'result.json'
    errors=pathlib.Path(directory)/'stderr.txt'
    subprocess.run(['open', '-n', '-W', '--stdout', str(output), '--stderr', str(errors), sys.argv[2], '--args', '--smoke-test'],check=True,timeout=15)
    check(output.read_text())
print('16 startup checks passed for direct launch and macOS app launch')
PY

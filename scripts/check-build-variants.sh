#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
import pathlib,plistlib
release=plistlib.loads(pathlib.Path('Resources/Info.plist').read_bytes())
app=pathlib.Path('dist/KLAP-Dev.app')
dev=plistlib.loads((app/'Contents/Info.plist').read_bytes())
assert dev['CFBundleName']==dev['CFBundleDisplayName']==dev['CFBundleExecutable']=='KLAP-Dev'
assert dev['CFBundleIdentifier']!=release['CFBundleIdentifier']
assert dev['KLAPDevelopmentBuild'] and not dev['SUEnableAutomaticChecks'] and not dev['SUAutomaticallyUpdate']
assert 'SUFeedURL' not in dev
for name in ('KLAP-Dev','KLAPBridge','CalendarBridge','ReminderBridge'):
    assert (app/'Contents/MacOS'/name).is_file(),name
assert (app/'Contents/Resources/KLAP.icns').is_file()
print('Development bundle identity, updater isolation and packaged executables passed')
PY
codesign --verify --deep --strict dist/KLAP-Dev.app
bash scripts/check-launch.sh dist/KLAP-Dev.app

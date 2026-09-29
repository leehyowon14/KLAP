#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Library/Developer/CommandLineTools}"
swift build --build-system native -c release --product KLAP
output="$(mktemp -d "${TMPDIR:-/tmp/}klap-updater-check.XXXXXX")"
trap 'rm -rf "$output"' EXIT
app="$output/KLAPUpdaterChecks.app"
mkdir -p "$app/Contents/MacOS"
cp Resources/Info.plist "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier dev.leehyowon.klap.updaterchecks' "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable UpdaterChecks' "$app/Contents/Info.plist"
framework=".build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64"
swiftc -swift-version 5 -F "$framework" -framework Sparkle -Xlinker -rpath -Xlinker @executable_path/../Frameworks Sources/KLAP/InstallationNotice.swift Sources/KLAP/UpdateTarget.swift Sources/KLAP/AppUpdater.swift Tests/KLAPUpdaterChecks/main.swift -o "$app/Contents/MacOS/UpdaterChecks"
bash scripts/embed-updater.sh "$app"
codesign --force --sign - "$app"
python3 - "$app" "$output" <<'PYFIX'
import pathlib, shutil, sys, plistlib, subprocess
app, root=map(pathlib.Path,sys.argv[1:])
for name in ['AppTranslocation/test/KLAP.app','original.app','tampered.app','different.app','unsigned.app']:
    target=root/name
    shutil.copytree(app,target,symlinks=True)
    if name=='tampered.app':
        (target/'Contents/Resources').mkdir(exist_ok=True)
        (target/'Contents/Info.plist').write_bytes((target/'Contents/Info.plist').read_bytes()+b' ')
    if name=='different.app':
        p=target/'Contents/Info.plist'; info=plistlib.loads(p.read_bytes());info['CFBundleVersion']='999';p.write_bytes(plistlib.dumps(info))
        subprocess.run(['codesign','--force','--sign','-',str(target)],check=True)
    if name=='unsigned.app':
        subprocess.run(['codesign','--remove-signature',str(target)],check=True)
PYFIX
"$app/Contents/MacOS/UpdaterChecks" "$output"

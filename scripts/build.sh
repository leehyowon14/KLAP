#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
variant="${1:---dev}"
case "$variant" in
  --dev) name=KLAP-Dev ;;
  --release) name=KLAP ;;
  *) echo 'Usage: bash scripts/build.sh [--dev|--release]' >&2; exit 1 ;;
esac
app="dist/$name.app"
swift build --build-system native -c release --product KLAP
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/KLAP "$app/Contents/MacOS/$name.next"
mv "$app/Contents/MacOS/$name.next" "$app/Contents/MacOS/$name"
python3 - "$app" "$name" <<'PY'
import pathlib,plistlib,sys
app,name=pathlib.Path(sys.argv[1]),sys.argv[2]
info=plistlib.loads(pathlib.Path('Resources/Info.plist').read_bytes())
info.update(CFBundleName=name,CFBundleDisplayName=name,CFBundleExecutable=name)
if name=='KLAP-Dev':
    info.update(CFBundleIdentifier='dev.leehyowon.klap.mac.dev',KLAPDevelopmentBuild=True,SUEnableAutomaticChecks=False,SUAutomaticallyUpdate=False)
    info.pop('SUFeedURL',None)
(app/'Contents/Info.plist').write_bytes(plistlib.dumps(info))
PY
bash scripts/build-icon.sh "$app"
bash scripts/build-core.sh "$app"
bash scripts/embed-updater.sh "$app"
codesign --force --sign - "$app"
echo "Built: $PWD/$app"

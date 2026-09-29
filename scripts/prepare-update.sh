#!/bin/bash
# Build the app first. This prepares signed release files; it does not publish them.
set -euo pipefail
cd "$(dirname "$0")/.."
tag="${1:?Usage: bash scripts/prepare-update.sh v0.2.0-beta [app-path]}"
app="${2:-dist/KLAP.app}"
[[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.-]+)?$ ]] || { echo "잘못된 릴리스 태그" >&2; exit 1; }
tools=".build/artifacts/sparkle/Sparkle/bin"
python3 - "$app" "$tag" <<'PY'
import pathlib,plistlib,sys,xml.etree.ElementTree as ET
app=pathlib.Path(sys.argv[1])
info=plistlib.loads((app/'Contents/Info.plist').read_bytes())
expected=plistlib.loads(pathlib.Path('Resources/Info.plist').read_bytes())
for key in ('CFBundleIdentifier','SUPublicEDKey','SUFeedURL'):
    if info.get(key)!=expected[key]:raise SystemExit(f'{key} 설정 불일치')
version=info['CFBundleShortVersionString']
if sys.argv[2]!='v'+version and not sys.argv[2].startswith('v'+version+'-'):
    raise SystemExit('태그와 앱 버전 불일치')
build=info['CFBundleVersion']
if not build.isdigit():raise SystemExit('CFBundleVersion은 증가하는 정수여야 합니다.')
root=ET.parse('Updates/appcast.xml')
versions=root.findall('.//{http://www.andymatuschak.org/xml-namespaces/sparkle}version')
old=[e.text for e in versions]
old += [e.get('{http://www.andymatuschak.org/xml-namespaces/sparkle}version') for e in root.findall('.//enclosure')]
if any(v and (not v.isdigit() or int(v)>=int(build)) for v in old):
    raise SystemExit('기존 피드보다 큰 CFBundleVersion이 필요합니다.')
PY
expected_key=$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$app/Contents/Info.plist")
actual_key=$("$tools/generate_keys" --account dev.leehyowon.klap.mac -p)
[[ "$expected_key" == "$actual_key" ]] || { echo "Keychain 서명키와 앱 공개키 불일치" >&2; exit 1; }
codesign --verify --deep --strict "$app"
output=".build/updates/$tag"
[[ ! -e "$output" ]] || { echo "$output 이미 존재합니다. 기존 산출물을 확인해 주세요." >&2; exit 1; }
mkdir -p "$output"
archive="$output/KLAP-$tag.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
cp Updates/appcast.xml "$output/appcast.xml"
"$tools/generate_appcast" --account dev.leehyowon.klap.mac --maximum-deltas 0 \
    --download-url-prefix "https://github.com/leehyowon14/KLAP/releases/download/$tag/" "$output"
python3 - "$output/appcast.xml" <<'PY'
import sys,xml.etree.ElementTree as ET
root=ET.parse(sys.argv[1]);items=root.findall('./channel/item')
if not items:raise SystemExit('업데이트 항목 생성 실패')
for item in items:
    enclosure=item.find('enclosure')
    if enclosure is None or not enclosure.get('{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature'):
        raise SystemExit('서명이 없는 업데이트 파일')
print('서명된 업데이트 피드 준비 완료')
PY
echo "Archive: $archive"
echo "Feed: $output/appcast.xml"

#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")/.."

if [[ -z "${DEVELOPER_DIR:-}" ]]; then
    DEVELOPER_DIR="$(/usr/bin/xcode-select -p 2>/dev/null || true)"
    [[ -n "$DEVELOPER_DIR" ]] || DEVELOPER_DIR=/Library/Developer/CommandLineTools
fi
export DEVELOPER_DIR

passed=0
failed=0
skipped=0
run_check() {
    local name="$1"
    shift
    printf '\n==> %s\n' "$name"
    if "$@"; then
        printf 'PASS: %s\n' "$name"
        ((passed+=1))
    else
        local result=$?
        printf 'FAIL: %s (exit %s)\n' "$name" "$result"
        ((failed+=1))
    fi
}
skip_check() {
    printf 'SKIP: %s — %s\n' "$1" "$2"
    ((skipped+=1))
}

run_check 'Core 모델과 경계값' swift run --build-system native KLAPCoreChecks
run_check 'Bridge JSON 스트리밍 프로토콜' bash scripts/check-bridge-protocol.sh
run_check '캘린더·미리 알림 권한 판단' bash scripts/check-permissions.sh
run_check '로그인 항목 상태' bash scripts/check-login-item.sh
run_check 'HTML 본문 로딩과 탐색 정책' bash scripts/check-html.sh
run_check '알림 생성과 권한 요청' bash scripts/check-notifications.sh
run_check '첨부파일 미리보기' bash scripts/check-preview.sh
run_check '업데이트 정책' bash scripts/check-updater.sh
run_check '설치 위치와 교체' bash scripts/check-installation.sh

core_ref="$(cat Bridge/core-ref)"
bridge_root=".build/cli-$core_ref"
if [[ -f "$bridge_root/go.mod" ]]; then
    run_check 'Go Bridge 수강 대기열' bash -c 'cd "$1" && go test ./cmd/klap-mac-bridge' _ "$bridge_root"
else
    skip_check 'Go Bridge 수강 대기열' 'Bridge/core-ref에 해당하는 KLAP_cli 소스가 .build에 없습니다.'
fi

if [[ -f "$bridge_root/bridges/macos/Sources/ReminderBridge/main.swift" ]]; then
    run_check '미리 알림 날짜·알람 정책' bash scripts/check-reminder-policy.sh
else
    skip_check '미리 알림 날짜·알람 정책' 'KLAP_cli의 ReminderBridge 소스를 빌드하지 않았습니다.'
fi

if [[ -d dist/KLAP-Dev.app ]]; then
    run_check '개발 번들·시작 화면' bash scripts/check-build-variants.sh
else
    skip_check '개발 번들·시작 화면' 'dist/KLAP-Dev.app 패키지가 없습니다. bash scripts/build.sh로 생성할 수 있습니다.'
fi

if [[ "${KLAP_RUN_UPDATE_INSTALL:-0}" == 1 ]]; then
    run_check '격리된 로컬 Sparkle 업데이트 설치' python3 scripts/check-update-install.py
else
    skip_check '격리된 로컬 Sparkle 업데이트 설치' '별도 프로세스와 임시 업데이트 앱을 실행합니다. KLAP_RUN_UPDATE_INSTALL=1로 명시해 실행하세요.'
fi

printf '\n결과: 통과 %s · 실패 %s · 건너뜀 %s\n' "$passed" "$failed" "$skipped"
if ((failed > 0)); then exit 1; fi

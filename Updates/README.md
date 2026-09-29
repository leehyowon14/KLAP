# 자동 업데이트 배포

Sparkle 2를 사용합니다. 앱은 매일 새 버전을 확인하고 기본적으로 다운로드 후 종료 시 설치합니다.
설정에서 자동 업데이트를 끄거나 수동 확인할 수 있습니다. 수강·동기화·초기 설정 중에는
업데이트 확인을 보류하고, 설치를 위한 재시작 요청도 작업이 끝날 때까지 지연합니다.

## 서명과 패키징

- Ed25519 개인키는 개발 Mac의 Keychain 계정 `dev.leehyowon.klap.mac`에 보관합니다.
- 공개키만 `Resources/Info.plist`에 포함합니다. 개인키를 Git 또는 릴리스에 넣지 않습니다.
- `scripts/build.sh`가 Sparkle.framework와 내부 updater/helper를 앱에 포함합니다.
- `SUVerifyUpdateBeforeExtraction`으로 압축 해제 전에 업데이트 서명을 검증합니다.
- 현재 앱의 ad hoc 서명과 Sparkle 업데이트 서명은 별개입니다. Developer ID 공증을 대신하지 않습니다.

## 릴리스 순서

1. `Resources/Info.plist`의 사용자 버전과 증가하는 정수 `CFBundleVersion`을 갱신합니다.
2. 빌드 및 테스트 후 `bash scripts/prepare-update.sh v0.2.0-beta`를 실행합니다.
3. 출력된 ZIP을 해당 태그의 GitHub Release에 업로드합니다.
4. 출력된 appcast.xml을 이 디렉터리로 복사하고, 실제 다운로드 URL이 성공하는지 확인합니다.
5. 피드를 포함한 릴리스 변경을 dev에서 main으로 반영합니다. 피드는 main의 raw URL을 사용합니다.
6. 이전 버전 설치본에서 업데이트 확인·서명 검사·교체·재실행을 확인합니다.

준비 스크립트는 파일을 생성하며 게시하지 않습니다. 기존 항목과 같은 빌드 번호 또는 낮은 번호는 거부합니다.
실제 ZIP 업로드보다 먼저 피드를 게시하지 마세요. 베타도 이 피드에 포함되면 모든 설치본에 전달됩니다.
현재 빈 피드는 첫 업데이트 배포 전의 상태입니다.

## 검증

- `bash scripts/check-updater.sh`: 작업 중 확인 보류, 재시작 지연, 반복 idle, 자동 업데이트 설정, 오류 표시
- `bash scripts/check-launch.sh`: Sparkle이 포함된 앱의 메뉴바 시작 회귀
- `bash scripts/prepare-update.sh <tag>`: 앱 서명·버전·공개키·아카이브 서명 확인

기존 0.1.0 Beta에는 Sparkle이 없으므로 최초 도입 버전은 수동 설치해야 합니다.

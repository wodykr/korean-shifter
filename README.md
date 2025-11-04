# Korean Shifter

Korean Shifter는 **왼쪽 Shift + Space** 키 조합으로 한/영 전환을 할 수 있게 해주는 가벼운 macOS 메뉴바 앱입니다. CGEvent tap을 통해 키보드 이벤트를 감지하고 TIS (Text Input Source) API를 사용하여 한글과 영어 입력 소스를 직접 전환합니다. 트리거 키를 누를 때 불필요한 공백이 입력되지 않도록 Input Monitoring과 Accessibility 권한이 모두 필요합니다.

> Xcode 프로젝트 파일과 소스 코드는 이전 이름인 `ShiftSpaceSwitcher` 디렉토리에 있습니다.

## 주요 기능

- ✅ 왼쪽 Shift 키(`keyCode 56`)와 Space 키(`keyCode 49`)만 감지하여 오동작을 방지합니다.
- ✅ TIS (Text Input Source) API를 직접 사용하여 안정적으로 입력 소스를 전환합니다.
- ✅ Input Monitoring과 Accessibility 권한을 모두 사용하여 단축키를 안정적으로 감지하고 공백 입력을 억제합니다.
- ✅ 영어/한글 화이트리스트 방식으로 지원되는 입력 소스 쌍이 없으면 메뉴가 비활성화되고 트리거가 무시됩니다.
- ✅ Shift를 누른 채로 Space를 여러 번 눌러 빠르게 전환할 수 있는 멀티탭 모드 (90ms 디바운스).
- ✅ 전환 시 "A" 또는 "가"를 0.45초 동안 표시하는 미니 HUD.
- ✅ 비밀번호 입력창 등의 보안 입력 상태를 감지하여 전환을 일시 중지하고 상태 아이콘 툴팁을 업데이트합니다.
- ✅ `.tapDisabledByTimeout` 및 `.tapDisabledByUserInput` 이벤트 발생 시 자동 복구.
- ✅ macOS 시작 시 자동 실행을 위한 로그인 항목 지원 (추가 권한 불필요).

## 프로젝트 구조

```
ShiftSpaceSwitcher/
├─ ShiftSpaceSwitcher.xcodeproj
└─ ShiftSpaceSwitcher/
   ├─ AppDelegate.swift
   ├─ EventTap.swift
   ├─ InputSwitch.swift
   ├─ Permissions.swift
   ├─ SecureInputMonitor.swift
   ├─ Settings.swift
   ├─ StatusMenu.swift
   ├─ TinyHUD.swift
   ├─ Info.plist
   └─ main.swift
```

## 빌드 및 실행

1. macOS 13+ 환경에서 Xcode 15 이상으로 `ShiftSpaceSwitcher.xcodeproj`를 엽니다.
2. **Korean Shifter** 스킴을 선택하고 빌드/실행합니다. 앱은 UI 요소로 실행되므로 Dock에 나타나지 않습니다.
3. 메뉴바 아이콘을 클릭하고 앱을 활성화합니다. **Input Monitoring**과 **Accessibility** 권한을 부여하라는 안내가 표시됩니다.
4. 두 권한을 모두 부여한 후 활성화 토글을 다시 클릭하여 앱을 활성화합니다.

## 사용 방법

- 메뉴바 아이콘은 현재 입력 언어를 표시합니다 (영어: "A", 한글: "가"). 권한이 없거나 보안 입력 상태일 때는 툴팁에 문제 설명이 표시됩니다.
- **활성화** 토글은 CGEvent tap을 활성화/비활성화합니다. 권한을 부여한 후 다시 클릭하여 tap을 재활성화해야 합니다.
- **한/영 전환 미니 알림**을 활성화하면 언어 전환 시 짧은 HUD 오버레이가 표시됩니다.
- Shift를 누른 채 Space를 반복해서 눌러 멀티탭 기능으로 빠르게 전환할 수 있습니다.
- **로그인 시 자동 실행**을 활성화하면 macOS 시작 시 앱이 자동으로 실행됩니다.
- **정보** 메뉴 항목에서 필요한 권한 정보를 확인할 수 있습니다.

## 필요한 권한

- **Input Monitoring** (필수): 왼쪽 Shift + Space 키 조합을 감지하기 위해 필요합니다.
  - 앱이 설치 후 자동으로 시스템 설정에 등록되도록 초기화합니다.
  - 설정 경로: `x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent`
- **Accessibility** (필수): 신뢰할 수 있는 event tap을 등록하고 트리거 Space 키를 억제하기 위해 필요합니다.
  - 첫 활성화 시 macOS 신뢰 프롬프트가 표시되며, 비활성 상태인 경우 설정 창을 엽니다.
  - 설정 경로: `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`

## 알려진 제한사항

- 프로젝트는 macOS 13 이상을 대상으로 합니다. 이전 버전에서는 배포 타겟 조정이 필요할 수 있습니다.
- 보안 입력 감지는 문서화되지 않은 `CGSIsSecureEventInputEnabled` 심볼을 사용하지만, 많은 유틸리티에서 일반적으로 사용되는 macOS 비공개 API입니다.
- Input Monitoring 또는 Accessibility 권한 중 하나라도 취소되면 앱은 두 권한이 모두 복원될 때까지 비활성화됩니다.

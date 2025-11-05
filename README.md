# Korean Shifter

Korean Shifter는 **왼쪽 Shift + Space** 키 조합으로 한/영 전환을 할 수 있게 해주는 가벼운 macOS 메뉴바 앱입니다. CGEvent tap을 통해 키보드 이벤트를 감지하고 TIS (Text Input Source) API를 사용하여 한글과 영어 입력 소스를 직접 전환합니다. 트리거 키를 누를 때 불필요한 공백이 입력되지 않도록 Input Monitoring과 Accessibility 권한이 모두 필요합니다.

> Xcode 프로젝트 파일과 소스 코드는 이전 이름인 `ShiftSpaceSwitcher` 디렉토리에 있습니다.

## 설치 방법

### 다운로드 및 설치

1. GitHub 저장소 페이지 우상단의 초록색 **<> Code** 버튼을 클릭합니다.
2. 드롭다운 메뉴에서 **Download ZIP**을 선택하여 전체 저장소를 다운로드합니다.
3. 다운로드한 ZIP 파일의 압축을 해제합니다.
4. 압축 해제된 폴더에서 `releases/Korean Shifter.app`을 찾아 `/Applications` 폴더로 이동합니다.
5. 앱을 실행하면 메뉴바에 아이콘이 나타납니다.
6. 메뉴바 아이콘을 클릭하고 **활성화**를 선택합니다.
7. **Input Monitoring**과 **Accessibility** 권한 요청이 표시되면 시스템 설정에서 권한을 부여합니다.
8. 권한을 부여한 후 메뉴바 아이콘을 다시 클릭하여 **활성화**를 토글하면 앱이 정상 작동합니다.

> **참고**: macOS에서 다운로드한 앱을 처음 실행할 때 보안 경고가 표시될 수 있습니다. 이 경우 앱을 우클릭(또는 Control+클릭)하고 "열기"를 선택하여 실행할 수 있습니다.

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

## 소스에서 빌드하기

개발자이거나 소스 코드에서 직접 빌드하려는 경우:

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

## 변경 이력 (Changelog)

### v0.1.2 (2025-11-05)
**개선 사항 (Code Quality)**
- 🐛 메모리 관리 이슈 수정
  - `Permissions.swift`: `kAXTrustedCheckOptionPrompt` 메모리 누수 수정 (takeRetainedValue → takeUnretainedValue)
  - `SecureInputMonitor.swift`: dlopen 핸들 메모리 누수 수정 (dlclose 추가)
- 🧹 코드 품질 개선
  - `EventTap.swift`: runLoopSource 중복 체크 제거
  - `AppDelegate.swift`: 불필요한 중복 권한 체크 제거
  - `TinyHUD.swift`: 사용되지 않는 빈 ConstrainedContentView 클래스 제거

### v0.1.1 (2025-11-04)
**초기 공개 릴리즈**
- ✨ 왼쪽 Shift + Space로 한/영 전환 기능
- ✨ 멀티탭 모드 (90ms 디바운스)
- ✨ 미니 HUD 전환 알림
- ✨ 보안 입력 감지
- ✨ 로그인 시 자동 실행
- ✨ Input Monitoring 및 Accessibility 권한 관리

## 라이선스 및 오픈소스

이 프로젝트는 개발자 본인이 필요해서 바이브코딩으로 뚝딱 만든 도구입니다. 🛠️

필요하신 분은 얼마든지 가져가서 마음대로 사용하시고, 뜯어고치고, 개선하고, 배포하셔도 됩니다.
상업적으로 사용하셔도 괜찮습니다. 뭐든지 하셔도 좋습니다!

**MIT License** 하에 배포됩니다.

```
MIT License

Copyright (c) 2025 Korean Shifter Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

만드신 것 중 좋은 개선사항이 있으면 PR 보내주시면 감사하겠습니다! 🙏

# 앱 이름: Korean Shifter

다음 프롬프트를 **그대로 Codex에 붙여넣어** 구현을 진행해 주세요. (맥OS 전용, Swift + AppKit)

---

# 프로젝트 목표

* **미니멀 메뉴바 에이전트 앱**으로, **왼쪽 Shift + Space** 조합으로만 **한/영 전환**을 수행합니다.
* **CGEventTap**을 사용한 **세 가지 전환 방식(A/B/C)** 중 **오직 하나만** 선택 가능하도록 합니다.
* **다른 시스템 전환키/단축키는 그대로 유지**합니다(앱은 간섭하지 않음).
* 공백 입력 방지: 전환 트리거가 성립하면 **Space 입력은 화면에 찍히지 않도록 소비**합니다.
* **오로지 영어/한국어만 지원**(C 방안은 ENG/KOR **하드코딩**). 한국어가 등록되어 있지 않거나, 다른 언어가 더 있을 경우 **전환 기능 비활성화(안전장치)** 합니다.

# 기술 스택 & 요구사항

* 언어/프레임워크: **Swift 5**, **AppKit**, `ApplicationServices`(Quartz), `Carbon.HIToolbox`(TIS)
* 앱 형태: 메뉴바 에이전트 (**`LSUIElement=YES`**), Dock/앱 스위처 표시 없음
* 권한:

  * **Input Monitoring** (CGEventTap 감시용, 필수)
  * **Accessibility** (A/C 방안에서 키 합성 시 필요)
* 샌드박스 비활성(전역 탭 제약 회피)
* 런루프: CGEventTap 소스는 **`.commonModes`** 에 등록
* 보안입력(Secure Input) 감지 시 전환 불가 안내(아이콘/툴팁 상태)

# 전환 트리거 로직

* **왼쪽 Shift(키코드 56)** 를 `flagsChanged`로 눌림/뗌 추적
* **Space(키코드 49)** 의 `keyDown` 수신 시:

  * 왼쪽 Shift가 눌려 있고
  * 오토리핏(`.keyboardEventAutorepeat == 1`)이 아니면
  * 선택된 방안(A/B/C)에 따라 **전환 수행** 후 **`return nil`** 로 **Space 이벤트 소비**
* 옵션: **멀티탭 모드** – Shift를 누른 채 Space를 짧게 여러 번 누를 때마다 연속 전환(디바운스 70–120ms)

# 전환 방안(세 가지)

* **A: CapsLock 합성**

  * CapsLock(키코드 57) **keyDown 1회**를 합성해(토글키) 전환합니다.
  * 전제: 사용자 시스템에서 **CapsLock=한/영 전환**으로 설정되어 있음.
  * 필요 권한: Input Monitoring + **Accessibility**
  * **무한루프 방지**: 합성 이벤트에 `eventSourceUserData` 태깅 후 탭 콜백에서 식별해 무시.
* **B: TIS 직접 전환(권장 기본값)**

  * `TISCopyCurrentKeyboardInputSource` → `TISSelectInputSource` 로 **ABC ↔ 2벌식** 토글.
  * 필요 권한: **Input Monitoring만**
  * 시스템 HUD(전환 애니메이션) **뜨지 않음**.
* **C: 시스템 단축키 합성(ENG/KOR 하드코딩)**

  * 예: **Option+Space**를 합성하여 시스템 설정된 전환 단축키를 대신 눌러줌.
  * 필요 권한: Input Monitoring + **Accessibility**
  * 시스템 HUD가 뜰 수 있으므로, “애니메이션 끄기”가 켜진 경우 **C는 비활성** 처리.

# 언어 지원 정책(중요)

* **영문/한글만 지원**합니다.
* 하드코딩 ID 화이트리스트:

  * ENG 후보: `com.apple.keylayout.ABC`, `com.apple.keylayout.US`
  * KOR 후보: `com.apple.inputmethod.Korean.2SetKorean`, `com.apple.inputmethod.Korean.3SetKorean`
* 현재 활성 입력소스가 위 리스트 밖(제3언어)이거나, 한국어가 미설치된 경우 → **전환 기능 비활성화**(메뉴에서 회색 처리/토스트 안내).

# UI/UX 사양

* 메뉴바 아이콘 1개(기본 문자 또는 이모지).
* **메뉴는 우클릭(또는 클릭) 시 표시**, 항목은 아래 순서/동작만 구현:

  1. **활성화 체크** (마스터 스위치; 끄면 이벤트 탭 비활성)
  2. **한/영 전환 애니메이션 끄기** 토글

     * 켜짐: 시스템 HUD 없이 전환(B/A 권장).
     * 켜져 있을 때 C 방안은 선택 불가(비활성 표시).
  3. **한/영 전환 미니 알림** 토글

     * 켜짐: 전환 직후 **초미니 HUD**(“A/가”) 300–500ms 표시
  4. ———— **구분선**
  5. **방안 A**, **방안 B**, **방안 C** (Radio, **오직 하나만 선택**)

     * 현재 선택 상태 표시; C는 “애니메이션 끄기”가 켜져 있으면 비활성
  6. ———— **구분선**
  7. **About** (버전/권한 상태 간단 표기)
  8. **Exit**
* **미니 알림(HUD)**: 무테/투명 NSWindow, 중앙 또는 메뉴바 아이콘 하단, 클릭스루, 페이드 인/아웃. 텍스트: “A” 또는 “가”.

# 동작 안전장치

* **Tap 타임아웃/사용자 비활성** 이벤트(`.tapDisabledByTimeout`, `.tapDisabledByUserInput`) 수신 시 **즉시 재활성화** 또는 **재설치**.
* **Secure Input** 발생 시 전환 불가 → 메뉴바 아이콘/툴팁으로 “보안 입력 중” 표시.
* 합성 이벤트 루프 방지: `eventSourceUserData` 태그 비교로 필터.
* 설정 영구화: **UserDefaults** (활성화/애니메이션/미니 알림/선택 방안/멀티탭 모드).

# 파일 구조(제안)

```
ShiftSpaceSwitcher/
  ├─ ShiftSpaceSwitcher.xcodeproj
  ├─ AppDelegate.swift
  ├─ EventTap.swift        // CGEventTap 설치/복구/핸들러
  ├─ InputSwitch.swift     // A/B/C 전환 로직, ENG/KOR 하드코딩/판별
  ├─ TinyHUD.swift         // 미니 알림 오버레이
  ├─ StatusMenu.swift      // 메뉴바 아이콘/메뉴 구성
  ├─ Permissions.swift     // 권한 열기/체크 유틸
  └─ Info.plist            // LSUIElement=YES
```

# 구현 디테일(필수)

* 왼쪽 Shift만 인식(키코드 **56**). Space는 **49**, CapsLock은 **57**.
* Space `keyDown`에서 전환이 발생하면 **반드시 `return nil`** 로 공백 차단.
* **오토리핏 무시**: `.keyboardEventAutorepeat == 1` 이면 전환/입력 모두 무시(`return nil`).
* **멀티탭 모드(옵션)**: Shift 유지 중 **Space 짧은 누름 마다 전환**, 디바운스 `minInterval ~90ms`.
* B 방안 기본값. “애니메이션 끄기” 기본 **켜짐**, “미니 알림” 기본 **꺼짐**.

# 권한/설정 단축열기

* Input Monitoring: `x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent`
* Accessibility: `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`

# 수용 기준(테스트)

1. Shift 없이 Space: **공백 정상 입력**(앱이 간섭하지 않음).
2. Shift+Space(짧게 1회): **전환 실행**, **공백 미입력**.
3. 멀티탭 모드: Shift 유지, Space 연타 → **회수만큼 전환**, 공백 없음, 과도 연타 시 디바운스 정상.
4. 방안 전환: A/B/C 중 선택 저장 및 즉시 반영, 재실행 후에도 유지.
5. “애니메이션 끄기”가 켜진 상태에서 C 방안 비활성(선택 불가).
6. 미니 알림 On: 전환 직후 “A/가” 0.3–0.5초 표시. Off: 표시 안 함.
7. 한국어 미설치/제3언어 활성: **전환 메뉴/기능 비활성** 및 안내.
8. Secure Input 중: 전환 불가 + 상태 안내, 해제 시 자동 복구.
9. Tap 타임아웃 발생 시 자동 재활성화/재설치로 회복.
10. 다른 시스템 전환키/단축키는 기존 동작 유지.

# 제외 범위(Out of Scope)

* 다국어(ENG/KOR 외) 지원, 사용자 정의 키맵, 프로파일링/로깅, 자동 업데이트, 설정 윈도우(Preferences Pane).

# 산출물

* 빌드 가능한 Xcode 프로젝트(위 구조).
* 핵심 로직은 **모듈 분리**(EventTap / InputSwitch / TinyHUD / StatusMenu).
* 코드에 **키코드/플래그/ID 상수**를 명확히 주석 첨부.
* README 한 장(권한 안내/최소 사용법).

---

이 사양에 맞춰 **동작하는 최소 제품(MVP)** 을 생성하세요.
특히 **CGEventTap 안정성(타임아웃 복구, Secure Input 대응)**, **공백 소비**, **ENG/KOR 하드코딩 안전장치**를 우선 구현하십시오.

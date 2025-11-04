# ShiftSpaceSwitcher

ShiftSpaceSwitcher is a lightweight macOS menu bar agent that forces Hangul/English switching to the **left Shift + Space** combination. It observes the shortcut via a CGEvent tap and uses the TIS (Text Input Source) API to toggle between Korean and English input sources. When Accessibility permission is granted, the tap consumes the space keystroke so no extra blank is typed; without it, the key press is passed through.

## Features

- ✅ Watches only the left shift key (`keyCode 56`) and the space bar (`keyCode 49`) to prevent accidental toggles.
- ✅ Uses direct TIS (Text Input Source) API for reliable switching - no synthetic events required.
- ✅ Works with just the Input Monitoring permission; optionally, grant Accessibility to let the app consume the trigger space key.
- ✅ Hardened by ENG/KOR whitelists. If the current machine does not provide a supported English/Korean pair, the menu is dimmed and the trigger is ignored.
- ✅ Optional multi-tap mode to chain multiple toggles while Shift is held (90 ms debounce).
- ✅ Tiny HUD overlay that flashes "A" or "가" for 0.45 seconds when enabled.
- ✅ Secure Input detection (e.g., password fields) pauses switching and updates the status icon tooltip.
- ✅ Automatic recovery from tap timeouts with `.tapDisabledByTimeout` and `.tapDisabledByUserInput` events.
- ✅ Login item support for automatic launch on macOS startup (no additional permissions required).

## Project layout

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

## Build & run

1. Open `ShiftSpaceSwitcher.xcodeproj` in Xcode 15 (or newer) on macOS 13+.
2. Select the **ShiftSpaceSwitcher** scheme and build/run. The app launches as a UI element, so it will not appear in the Dock.
3. Click the menu bar icon and enable the app. You will be prompted to grant **Input Monitoring** permission.
4. After granting permission, click the enable toggle again to activate the app.

## Usage tips

- The menu bar icon displays the active layout ("A" for English, "가" for Korean). When permissions are missing or Secure Input is active, the tooltip explains the issue.
- The **활성화** toggle enables/disables the CGEvent tap; click again after granting permissions to reactivate the tap.
- **한/영 전환 미니 알림** shows a brief HUD overlay when switching languages.
- **한/영 전환 애니메이션 끄기** lets you keep the HUD text but disable the fade-in/out animation.
- **멀티탭 모드** lets you keep Shift held and tap Space repeatedly to swap back and forth.
- **로그인 시 자동 실행** registers the app to launch automatically on macOS startup.
- The **About** item summarizes the required permissions.

## Permissions

- **Input Monitoring** (required): Allows the app to observe the left Shift + Space key combination
  - The app will automatically open System Settings when you first enable it
  - URL: `x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent`
- **Accessibility** (optional): Lets the app suppress the space character when a switch occurs
  - Without this permission, layout switching works but a trailing space remains
  - URL: `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`

## Known limitations

- The project targets macOS 13+. Earlier systems may require deployment target adjustments.
- Secure Input detection relies on the undocumented `CGSIsSecureEventInputEnabled` symbol, which is commonly used in utilities but remains private to macOS.
- Without Accessibility permission, the app must let the space keystroke pass through; enable it to have the switch consume the space key.

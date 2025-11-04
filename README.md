# Korean Shifter

ShiftSpaceSwitcher is a lightweight macOS menu bar agent that forces Hangul/English switching to the **left Shift + Space** combination. It installs a CGEvent tap, consumes the space key when the trigger is satisfied, and lets you choose from the three switching strategies defined in the original specification.

## Features

- ✅ Watches only the left shift key (`keyCode 56`) and the space bar (`keyCode 49`) to prevent accidental toggles.
- ✅ Guarantees that space characters are never forwarded when a language switch is triggered.
- ✅ Supports all three requested switching strategies:
  - **Plan A – Caps Lock synthesis** (requires Accessibility permission).
  - **Plan B – Direct TIS input source toggle** (default, no Accessibility permission required).
  - **Plan C – Option+Space shortcut synthesis** (requires Accessibility permission and the animation toggle to be off).
- ✅ Hardened by ENG/KOR whitelists. If the current machine does not provide a supported English/Korean pair, the menu is dimmed and the trigger is ignored.
- ✅ Optional multi-tap mode to chain multiple toggles while Shift is held (90 ms debounce).
- ✅ Tiny HUD overlay that flashes “A” or “가” for 0.45 seconds when enabled.
- ✅ Secure Input detection (e.g., password fields) pauses switching and updates the status icon tooltip.
- ✅ Automatic recovery from tap timeouts with `.tapDisabledByTimeout` and `.tapDisabledByUserInput` events.

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
3. Grant **Input Monitoring** permission on first launch. For plans A or C, also grant **Accessibility** permission.

## Usage tips

- The menu bar icon displays the active layout (“A” for English, “가” for Korean). When permissions are missing or Secure Input is active, the tooltip explains the issue.
- The **활성화** toggle disables the CGEvent tap entirely; click again after granting permissions to reactivate the tap.
- **한/영 전환 애니메이션 끄기** must remain off to enable Plan C (shortcut synthesis).
- **멀티탭 모드** lets you keep Shift held and tap Space repeatedly to swap back and forth.
- The **About** item summarises the required permissions and current version.

## Permissions shortcuts

- Input Monitoring: `x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent`
- Accessibility: `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`

## Known limitations

- The project targets macOS 13+. Earlier systems may require deployment target adjustments.
- Secure Input detection relies on the undocumented `CGSIsSecureEventInputEnabled` symbol, which is commonly used in utilities but remains private to macOS.

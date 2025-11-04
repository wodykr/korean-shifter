# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ShiftSpaceSwitcher is a macOS menu bar agent that enables Korean/English language switching using the left Shift + Space combination. It uses CGEvent tap to intercept keyboard events and directly toggles the input source using the TIS (Text Input Source) API.

## Build Commands

**Build and run in Xcode:**
```bash
open ShiftSpaceSwitcher.xcodeproj
# Then use Xcode's build/run (Cmd+R)
```

**Build from command line:**
```bash
xcodebuild -project ShiftSpaceSwitcher.xcodeproj -scheme ShiftSpaceSwitcher -configuration Release build
```

**Requirements:**
- Xcode 15+
- macOS 13+ (required for login item functionality)
- Input Monitoring permission (required for keyboard event interception)

**Permissions:**
- **Input Monitoring** (required): Allows the app to intercept left Shift + Space key combinations
  - Users are prompted to grant this permission when they first enable the app
  - App automatically opens System Settings > Privacy & Security > Input Monitoring
- **Login Item** (no additional permission required): Users can enable "Launch at Login" from the menu
  - Uses SMAppService API (macOS 13+) which doesn't require special entitlements
  - Setting is registered with the system and persists across reboots

## Architecture

### Core Components

**AppDelegate.swift** - Main coordinator orchestrating all components
- Manages Input Monitoring permission state (detects via EventTap success/failure)
- Coordinates between EventTap, InputSwitch, and UI components
- Handles secure input detection state changes
- Implements StatusMenuDelegate for user settings changes
- Syncs login item state with system on launch

**EventTap.swift** - CGEvent tap for keyboard interception
- Monitors keyCode 56 (left Shift) and keyCode 49 (Space)
- Maintains state: leftShiftPressed, triggeredDuringCurrentHold
- Auto-recovers from .tapDisabledByTimeout and .tapDisabledByUserInput
- Implements multi-tap mode with 90ms debounce
- Uses CGEvent tap in two modes: observe-only (default) or consume (when Accessibility permission granted); switchHandler returns SwitchAction (.switched, .ignored)

**InputSwitch.swift** - Language switching using TIS API
- Uses direct TIS (Text Input Source) toggle method only
- Whitelist-based: only switches between supported English/Korean pairs
- English sources: ABC, US
- Korean sources: 2SetKorean, 3SetKorean
- No synthetic events needed (direct API calls don't trigger EventTap)

**StatusMenu.swift** - Menu bar UI
- Displays current language ("A" or "가")
- Shows permission status in tooltip when issues detected
- Menu items mirror enabled/disabled state based on permissions/configuration

**SecureInputMonitor.swift** - Detects password fields
- Uses private CGSIsSecureEventInputEnabled API
- Polls every 0.2s to detect secure input state
- Switches are ignored while secure input is active

**TinyHUD.swift** - Visual feedback overlay
- Shows "A" or "가" for 0.45 seconds when language switches
- Optional feature controlled by showMiniHUD setting

**Settings.swift** - UserDefaults persistence for user preferences
- isEnabled: Master switch for the app functionality
- showMiniHUD: Whether to show visual feedback on language switch
- multiTapEnabled: Whether to allow multiple switches during single Shift hold
- loginItemEnabled: Whether to launch app at login

**LoginItemManager.swift** - Login item management (macOS 13+)
- Uses SMAppService.mainApp API to register/unregister with system
- No additional permissions or entitlements required
- Synced with settings on app launch

**Permissions.swift** - System permission helpers and URL openers

### Key Design Patterns

**Permission Handling Flow:**
1. On launch, AppDelegate attempts to start EventTap
2. If Input Monitoring permission is missing → settings.isEnabled is cleared and the UI directs the user to System Settings
3. Accessibility permission is optional: without it the tap runs in observe-only mode, with it the app consumes the trigger space key
4. When the user enables the app without Input Monitoring permission:
   - Calls IOHIDRequestAccess() to trigger the system prompt
   - Opens System Settings > Privacy & Security > Input Monitoring
5. When Accessibility permission is absent, the app prompts (via AXIsProcessTrustedWithOptions) and opens the Accessibility pane, but still operates in observe-only mode
6. Permission revocation is detected via EventTap failure, and the UI updates the state accordingly

**Event Flow:**
1. EventTap detects left Shift down (flagsChanged, keyCode 56)
2. EventTap detects Space down (keyDown, keyCode 49)
3. Calls switchHandler() in AppDelegate → handleSwitchRequest()
4. AppDelegate checks: enabled, permissions, supported pair, secure input
5. Calls InputSwitch.toggle() which uses TIS API to switch input source
6. Returns SwitchAction:
   - .switched: Input source changed successfully (HUD may display)
   - .ignored: Conditions failed; keystroke is untreated

**State Synchronization:**
- AppDelegate.refreshState() is the single source of truth
- Called after permission changes, setting changes, tap state changes
- Rebuilds StatusMenu.Context with current state and calls statusMenu.update()
- Syncs loginItemEnabled setting with actual SMAppService state on launch

### Important Constraints

**Multi-tap Mode:**
- When enabled: allows repeated Space presses while Shift held (90ms debounce)
- When disabled: only first Space press triggers switch during Shift hold
- Controlled by triggeredDuringCurrentHold flag reset on Shift release

**Secure Input Detection:**
- When active (e.g., password fields), switchHandler returns .ignored
- The app still lets the keystroke pass through while refusing to change layouts

## File Structure

```
ShiftSpaceSwitcher/
├─ ShiftSpaceSwitcher.xcodeproj
└─ ShiftSpaceSwitcher/
   ├─ main.swift               # Entry point, sets up NSApplication
   ├─ AppDelegate.swift         # Main coordinator
   ├─ EventTap.swift            # CGEvent tap for keyboard interception
   ├─ InputSwitch.swift         # Language switching logic using TIS API
   ├─ StatusMenu.swift          # Menu bar UI
   ├─ TinyHUD.swift            # Visual feedback overlay
   ├─ SecureInputMonitor.swift  # Password field detection
   ├─ LoginItemManager.swift    # Login item management (macOS 13+)
   ├─ Settings.swift           # UserDefaults wrapper
   ├─ Permissions.swift        # Permission helpers
   └─ Info.plist               # Bundle configuration
```

## Testing Considerations

**Manual Testing Checklist:**
- Test without Input Monitoring permission (app should be disabled, prompt on enable)
- Test switching in secure input contexts like password fields (should ignore the request)
- Test multi-tap mode vs single-tap mode behavior
- Test recovery from CGEvent tap timeout (happens after ~60 seconds of inactivity)
- Test with unsupported input sources (non-whitelisted languages should not switch)
- Verify HUD shows correct symbol after switch ("A" or "가")
- Verify status icon reflects current language correctly
- Test login item functionality (enable, restart Mac, verify app auto-launches)
- Test permission revocation while running (remove Input Monitoring, verify app auto-disables)
- Toggle Accessibility permission on/off to confirm the app falls back to observe-only mode (space passes through)

**Known Private API Usage:**
- CGSIsSecureEventInputEnabled (in SecureInputMonitor.swift) - widely used but undocumented
  - Loaded dynamically at runtime using `dlsym` to avoid linker issues
  - Gracefully falls back if symbol cannot be loaded (assumes secure input is inactive)

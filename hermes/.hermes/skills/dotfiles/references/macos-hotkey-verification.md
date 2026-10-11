# Verifying a global macOS hotkey end-to-end

Use after binding or changing a Hammerspoon (or similar) global hotkey: prove the binding actually fires and lands on the target app, rather than trusting the config reload.

## Why synthetic keystrokes

`osascript`'s ` keystroke` fails with "osascript is not allowed to send keystrokes" unless it holds Accessibility permission, and agent tooling may not have it. A compiled Swift CGEvent poster has the same constraint on delivery but is cheap to build and makes the failure observable — and critically, test the CONTROL case first so you can tell "delivery works" from "binding broken".

## Procedure

1. Write a tiny poster (keycode as argv, ⌃⌘ modifiers hard-coded) and compile:

    ```swift
    import CoreGraphics
    import Foundation
    let args = CommandLine.arguments
    let keyCode = CGKeyCode(truncatingIfNeeded: Int(args[1]) ?? 0)
    func postEvent(_ keyDown: Bool) {
        guard let ev = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: keyDown) else { exit(1) }
        ev.flags = [.maskControl, .maskCommand]
        ev.post(tap: .cghidEventTap)
    }
    postEvent(true)
    usleep(60_000)
    postEvent(false)
    ```

    `swiftc poster.swift -o poster` (or `swift poster.swift` if no swiftc).

2. Read frontmost app between steps:

    ```bash
    FRONTMOST() { osascript -e 'tell application "System Events" to get bundle identifier of first application process whose frontmost is true'; }
    ```

3. Test in this exact order:
   - Focus some other app first (e.g. Ghostty/Finder) — otherwise the target already being frontmost makes the test unobservable.
   - Post an ALREADY-EXISTING binding's key (e.g. ⌃⌘P → Finder). If the frontmost app switches to that binding's target, CGEvent delivery works — only then is a negative result on the new key meaningful.
   - Post the NEW binding's key. Frontmost switching to the new target = verified.

## Pitfalls

- Never name AppleScript variables `before`/`after` — reserved keywords; the script fails to parse with "Expected expression".
- CGEventPost succeeding means the event was posted, not delivered — always confirm via the frontmost-app check, and use the control-binding step to separate delivery failure from binding failure.
- Hammerspoon's `hs` IPC CLI errors "can't access Hammerspoon message port" unless the ipc module is loaded; restart Hammerspoon (`killall Hammerspoon && sleep 1 && open -a Hammerspoon`) to reload config instead.

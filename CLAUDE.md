# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A macOS menu bar app (SwiftPM executable, no Xcode project) that controls mitmproxy: toggling the system HTTP/HTTPS proxy, starting/stopping the `mitmweb` console, mocking API endpoints (response overrides), and a dev CORS bypass. It runs as an `LSUIElement` accessory app (no dock icon), and the **entire UI is a single `MenuBarExtra(.window)` popup** — there are no other windows.

## Commands

```bash
# Build (debug)
swift build

# Build release + assemble MITMMenuBar.app bundle
./build.sh

# Run the raw binary
.build/release/MITMMenuBar        # or .build/debug/MITMMenuBar

# Run the app bundle
open MITMMenuBar.app
```

There is no test suite and no linter configured. VS Code launch configs live in `.vscode/launch.json` (uses the sswg Swift extension).

To run mitmproxy features locally you need `brew install mitmproxy`. The proxy toggle shells out to `/usr/sbin/networksetup`, which may prompt for an admin password.

## Architecture

Swift files under `Sources/MITMMenuBar/`. This is a **SwiftUI `App`-lifecycle** app (not AppKit/`AppDelegate` — that was removed):

- **`MITMMenuBarApp.swift`** — `@main struct ... : App`. One `MenuBarExtra { MenuContentView } label: { StatusLabel }` scene with `.menuBarExtraStyle(.window)`. Owns the three managers as `@StateObject`. `StatusLabel` renders the menu-bar icon: the menu bar forces monochrome *template* rendering, so to show **color** it builds a pre-tinted **non-template** `NSImage` (`lockFocus` + `sourceAtop` fill, `isTemplate = false`) via `Image(nsImage:)`. It also seeds an initial status check in a `.task`.
- **`MenuContentView.swift`** — the whole popup UI. Proxy/console toggles, "Turn Everything On/Off", console-port field, "Open Web UI", "Bypass CORS" toggle, and the inline override list (`RuleRow` = a `DisclosureGroup`; the JSON `TextEditor` is drag-resizable via a corner grip + `DragGesture`). Persists edits with `.onChange(of:)` → `overrides.save()`.
- **`OverridesStore.swift`** — `ObservableObject` owning override rules + `corsBypass`, persisted to `~/.mitmmenubar/overrides.json`. Also holds `OverridePaths`, the `OverrideRule` model, and the **embedded Python addon** (`addonScript`) written to `~/.mitmmenubar/response_override.py` on launch.
- **`ProxyManager.swift`** — `ObservableObject` wrapping `networksetup`. `enable()`/`disable()` set HTTP + HTTPS proxy; `checkStatus()` parses `-getwebproxy` and only reports enabled when host+port (`127.0.0.1:8080`) match, ignoring unrelated proxies.
- **`MitmwebManager.swift`** — `ObservableObject` managing the `mitmweb` process. `start()` searches Homebrew paths then falls back to `which`; status via `pgrep -f mitmweb`, stop via `pkill -f mitmweb` (manages *any* mitmweb instance). `webPort` is persisted via `UserDefaults` and passed as `--web-port`; `applyPortChange()` restarts mitmweb if running.

### The mitmproxy addon (`OverridesStore.addonScript`)
The Swift app and a Python addon share `~/.mitmmenubar/overrides.json`. The addon re-reads that file (mtime-cached) on each request, so **rule/CORS edits apply live without restarting mitmweb** — only changes to the addon *code* need a console restart (mitmproxy hot-reloads `-s` scripts on file change, which the app rewrites at launch). The addon: short-circuits matching requests in the `request` hook (upstream never contacted), answers CORS preflight `OPTIONS`, always adds CORS headers to mocks, and — when `corsBypass` is on — injects CORS headers into all passed-through responses in the `response` hook. Origin is reflected (not `*`) so credentialed requests work.

### Gotchas
- **Don't mutate `@Published` from a manager's `init()`.** Seeding status there (which dispatches `@Published` writes) crashes SwiftUI's AttributeGraph at launch. Initial status is seeded from `StatusLabel`'s `.task` instead.
- **Proxy/console are coupled** in `MenuContentView`: enabling the proxy also starts the console; stopping the console disables the proxy. This makes the `(proxy on, console off)` state — which black-holes all traffic ("no internet") — unreachable. That state shows a red warning icon if reached externally.
- No continuous polling: status refreshes on popup open (`.onAppear`, which also calls `NSApp.activate` so text fields accept paste) and after toggles (`asyncAfter`). All `@Published` mutations are marshaled to the main queue.

### Configuration
- **In-app:** console web-UI port (`MitmwebManager.webPort`, `UserDefaults`).
- **Hardcoded:** proxy host/port/interface (`127.0.0.1:8080`, `Wi-Fi`) in `ProxyManager`; `--ignore-hosts` list in `MitmwebManager`.

## Notes

- `Package.swift` excludes `Resources/Info.plist` from the build; `build.sh` copies it into the `.app` bundle. `LSUIElement = true` in Info.plist is what makes it an accessory (no dock icon) under the SwiftUI lifecycle. Bundle identifier is `com.local.MITMMenuBar`.
- Info.plist still carries a stale `NSAppleEventsUsageDescription` about controlling Warp; the app no longer uses AppleEvents/Warp.

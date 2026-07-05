# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A macOS menu bar app (SwiftPM executable, no Xcode project) that controls mitmproxy: toggling the system HTTP/HTTPS proxy and starting/stopping the `mitmweb` console. It runs as an `LSUIElement` accessory app (no dock icon), driven entirely from the status bar menu.

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

Three source files under `Sources/MITMMenuBar/`, wired together by `AppDelegate`:

- **`MITMMenuBarApp.swift`** — `@main` entry point. Manually constructs `NSApplication`, sets `.accessory` activation policy, installs `AppDelegate`.
- **`AppDelegate.swift`** — owns the `NSStatusItem`, menu, and both managers. Subscribes to the managers' `@Published` state via Combine (`setupBindings`) and re-renders the menu-bar icon (`updateStatusIcon`) whenever either changes. The icon is an SF Symbol tinted per state — the four (proxyOn, webConsoleOn) combinations map to distinct symbol+color pairs. `NSImage.tinted(with:)` extension does the coloring (sets `isTemplate = false` so the tint survives).
- **`ProxyManager.swift`** — `ObservableObject` wrapping `networksetup`. `enable()`/`disable()` set HTTP + HTTPS proxy; `checkStatus()` parses `-getwebproxy` output and only reports enabled when the configured host+port (`127.0.0.1:8080`) match, so it ignores unrelated proxies.
- **`MitmwebManager.swift`** — `ObservableObject` managing the `mitmweb` process. `start()` searches known Homebrew paths then falls back to `which`. Status detection uses `pgrep -f mitmweb` and stop uses `pkill -f mitmweb`, so it manages *any* mitmweb instance, not just the one it launched.

### State model
There is no continuous polling. Status is refreshed only on `applicationDidFinishLaunching` and via `menuWillOpen` (the `NSMenuDelegate` callback) when the user opens the menu. After a toggle, managers re-check status on a short `asyncAfter` delay to let the system settle. All `@Published` mutations are marshaled to the main queue.

### Hardcoded configuration
Settings are constants in the manager files, not user-configurable at runtime:
- `ProxyManager`: `proxyHost = 127.0.0.1`, `proxyPort = 8080`, `networkService = "Wi-Fi"` (proxy toggling only affects the Wi-Fi interface).
- `MitmwebManager`: `mitmwebArguments` passes `--ignore-hosts` for Apple/iCloud/mzstatic domains.
- `openWebUI` opens `http://127.0.0.1:8081` (mitmweb's default web UI port).

## Notes

- The README's "launch mitmweb in Warp terminal" / Accessibility-permission sections are **stale**: the current code launches `mitmweb` directly as a subprocess (output to `/dev/null`) and does not send keystrokes to Warp. Prefer the code over the README when they disagree.
- `Package.swift` excludes `Resources/Info.plist` from the build; `build.sh` copies it into the `.app` bundle. Bundle identifier is `com.local.MITMMenuBar`.

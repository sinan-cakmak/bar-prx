import AppKit
import SwiftUI

/// Hosts the SwiftUI overrides editor in a standalone window. Since the app is
/// an accessory (no dock), callers should `NSApp.activate` before showing it.
final class OverridesWindowController: NSWindowController {
    convenience init(store: OverridesStore) {
        let hosting = NSHostingController(rootView: OverridesView(store: store))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Response Overrides"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 720, height: 460))
        window.isReleasedWhenClosed = false
        window.center()
        self.init(window: window)
    }
}

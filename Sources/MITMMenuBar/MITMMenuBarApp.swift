import SwiftUI

@main
struct MITMMenuBarApp: App {
    @StateObject private var proxy = ProxyManager()
    @StateObject private var mitmweb = MitmwebManager()
    @StateObject private var overrides = OverridesStore()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(proxy: proxy, mitmweb: mitmweb, overrides: overrides)
        } label: {
            StatusLabel(proxy: proxy, mitmweb: mitmweb)
        }
        .menuBarExtraStyle(.window)
    }
}

/// The menu bar icon. Its color reflects the current proxy/console state, and it
/// seeds an initial status check on launch so it's accurate before the popup opens.
private struct StatusLabel: View {
    @ObservedObject var proxy: ProxyManager
    @ObservedObject var mitmweb: MitmwebManager

    var body: some View {
        // Menu bar renders SwiftUI symbols as monochrome templates, so to reflect
        // state with color we hand it a pre-tinted, non-template image.
        Image(nsImage: statusIcon)
            .task {
                proxy.checkStatus()
                mitmweb.checkStatus()
            }
    }

    private var statusIcon: NSImage {
        let (symbol, color): (String, NSColor)
        switch (proxy.isEnabled, mitmweb.isRunning) {
        case (false, false): (symbol, color) = ("network.slash", .secondaryLabelColor)          // both off
        case (true, false):  (symbol, color) = ("exclamationmark.triangle.fill", .systemRed)    // proxy on, no server → no internet
        case (true, true):   (symbol, color) = ("network.badge.shield.half.filled", .systemGreen) // both on
        case (false, true):  (symbol, color) = ("shield.lefthalf.filled", .systemYellow)         // console only
        }

        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        guard let base = NSImage(systemSymbolName: symbol, accessibilityDescription: "MITM status")?
            .withSymbolConfiguration(config),
              let tinted = base.copy() as? NSImage else {
            return NSImage()
        }

        tinted.lockFocus()
        color.set()
        NSRect(origin: .zero, size: tinted.size).fill(using: .sourceAtop)
        tinted.unlockFocus()
        tinted.isTemplate = false
        return tinted
    }
}

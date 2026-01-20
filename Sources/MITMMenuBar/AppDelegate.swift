import AppKit
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    
    private let proxyManager = ProxyManager()
    private let mitmwebManager = MitmwebManager()
    
    private var proxyMenuItem: NSMenuItem!
    private var webConsoleMenuItem: NSMenuItem!
    private var openWebUIMenuItem: NSMenuItem!
    
    private var statusTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupMenu()
        setupBindings()
        startStatusPolling()
        
        // Initial status check
        proxyManager.checkStatus()
        mitmwebManager.checkStatus()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        statusTimer?.invalidate()
    }
    
    // MARK: - Setup
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "network.slash", accessibilityDescription: "MITM Proxy")
            button.image?.isTemplate = true
        }
    }
    
    private func setupMenu() {
        menu = NSMenu()
        
        // Proxy toggle
        proxyMenuItem = NSMenuItem(
            title: "Proxy Enabled",
            action: #selector(toggleProxy),
            keyEquivalent: "p"
        )
        proxyMenuItem.target = self
        menu.addItem(proxyMenuItem)
        
        // Web console toggle
        webConsoleMenuItem = NSMenuItem(
            title: "Web Console",
            action: #selector(toggleWebConsole),
            keyEquivalent: "w"
        )
        webConsoleMenuItem.target = self
        menu.addItem(webConsoleMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Open Web UI
        openWebUIMenuItem = NSMenuItem(
            title: "Open mitmproxy Web UI",
            action: #selector(openWebUI),
            keyEquivalent: "o"
        )
        openWebUIMenuItem.target = self
        menu.addItem(openWebUIMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitMenuItem = NSMenuItem(
            title: "Quit",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitMenuItem.target = self
        menu.addItem(quitMenuItem)
        
        statusItem.menu = menu
    }
    
    private func setupBindings() {
        // Update UI when proxy status changes
        proxyManager.$isEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEnabled in
                self?.proxyMenuItem.state = isEnabled ? .on : .off
                self?.updateStatusIcon()
            }
            .store(in: &cancellables)
        
        // Update UI when mitmweb status changes
        mitmwebManager.$isRunning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRunning in
                self?.webConsoleMenuItem.state = isRunning ? .on : .off
                self?.openWebUIMenuItem.isEnabled = isRunning
                self?.updateStatusIcon()
            }
            .store(in: &cancellables)
    }
    
    private func startStatusPolling() {
        // Poll every 2 seconds to keep status in sync
        statusTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.proxyManager.checkStatus()
            self?.mitmwebManager.checkStatus()
        }
    }
    
    // MARK: - Icon Updates
    
    private func updateStatusIcon() {
        guard let button = statusItem.button else { return }
        
        let proxyOn = proxyManager.isEnabled
        let webConsoleOn = mitmwebManager.isRunning
        
        let symbolName: String
        let symbolColor: NSColor
        
        switch (proxyOn, webConsoleOn) {
        case (false, false):
            symbolName = "network.slash"
            symbolColor = .secondaryLabelColor
        case (true, false):
            symbolName = "network"
            symbolColor = .systemBlue
        case (true, true):
            symbolName = "network.badge.shield.half.filled"
            symbolColor = .systemGreen
        case (false, true):
            symbolName = "network"
            symbolColor = .systemYellow
        }
        
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "MITM Proxy Status") {
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
            let configuredImage = image.withSymbolConfiguration(config)
            
            // Apply color tint
            let coloredImage = configuredImage?.tinted(with: symbolColor)
            button.image = coloredImage
        }
    }
    
    // MARK: - Actions
    
    @objc private func toggleProxy() {
        if proxyManager.isEnabled {
            proxyManager.disable()
        } else {
            proxyManager.enable()
        }
    }
    
    @objc private func toggleWebConsole() {
        if mitmwebManager.isRunning {
            mitmwebManager.stop()
        } else {
            mitmwebManager.start()
        }
    }
    
    @objc private func openWebUI() {
        if let url = URL(string: "http://127.0.0.1:8081") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - NSImage Extension for Tinting

extension NSImage {
    func tinted(with color: NSColor) -> NSImage {
        let image = self.copy() as! NSImage
        image.lockFocus()
        
        color.set()
        
        let imageRect = NSRect(origin: .zero, size: image.size)
        imageRect.fill(using: .sourceAtop)
        
        image.unlockFocus()
        image.isTemplate = false
        
        return image
    }
}

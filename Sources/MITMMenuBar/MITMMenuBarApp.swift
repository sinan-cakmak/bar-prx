import AppKit

@main
struct MITMMenuBarApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        
        // Don't show in dock (menu bar only app)
        app.setActivationPolicy(.accessory)
        
        app.run()
    }
}

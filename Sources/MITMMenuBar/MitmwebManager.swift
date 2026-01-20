import Foundation
import Combine
import AppKit

class MitmwebManager: ObservableObject {
    @Published private(set) var isRunning: Bool = false
    
    private let mitmwebCommand = "mitmweb --ignore-hosts '.*\\.apple\\.com:443$|.*\\.icloud\\.com:443$|.*\\.mzstatic\\.com:443$'"
    
    // MARK: - Public Methods
    
    func start() {
        launchInWarp()
        
        // Check status after a delay to allow mitmweb to start
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.checkStatus()
        }
    }
    
    func stop() {
        killMitmweb()
        
        // Update status after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkStatus()
        }
    }
    
    func checkStatus() {
        let isRunning = isMitmwebRunning()
        
        DispatchQueue.main.async { [weak self] in
            self?.isRunning = isRunning
        }
    }
    
    // MARK: - Private Methods
    
    private func launchInWarp() {
        // Use AppleScript to launch command in Warp terminal
        let script = """
        tell application "Warp"
            activate
            delay 0.5
        end tell
        
        tell application "System Events"
            tell process "Warp"
                keystroke "n" using command down
                delay 0.3
                keystroke "\(mitmwebCommand)"
                keystroke return
            end tell
        end tell
        """
        
        runAppleScript(script)
    }
    
    private func killMitmweb() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        process.arguments = ["-f", "mitmweb"]
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("Failed to kill mitmweb: \(error)")
        }
    }
    
    private func isMitmwebRunning() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-x", "mitmweb"]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
            
            // pgrep returns 0 if a process is found
            return process.terminationStatus == 0
        } catch {
            print("Failed to check mitmweb status: \(error)")
            return false
        }
    }
    
    private func runAppleScript(_ script: String) {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            
            if let error = error {
                print("AppleScript error: \(error)")
                
                // Fallback: try using osascript directly
                fallbackLaunchInWarp()
            }
        }
    }
    
    private func fallbackLaunchInWarp() {
        // Alternative approach using osascript
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [
            "-e", "tell application \"Warp\" to activate",
            "-e", "delay 0.5",
            "-e", "tell application \"System Events\" to tell process \"Warp\" to keystroke \"n\" using command down",
            "-e", "delay 0.3",
            "-e", "tell application \"System Events\" to tell process \"Warp\" to keystroke \"\(mitmwebCommand)\"",
            "-e", "tell application \"System Events\" to tell process \"Warp\" to keystroke return"
        ]
        
        do {
            try process.run()
        } catch {
            print("Failed to launch Warp with fallback: \(error)")
        }
    }
}

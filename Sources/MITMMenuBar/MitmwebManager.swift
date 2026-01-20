import Foundation
import Combine

class MitmwebManager: ObservableObject {
    @Published private(set) var isRunning: Bool = false
    
    private var mitmwebProcess: Process?
    
    private let mitmwebArguments = [
        "--ignore-hosts", ".*\\.apple\\.com:443$|.*\\.icloud\\.com:443$|.*\\.mzstatic\\.com:443$"
    ]
    
    // MARK: - Public Methods
    
    func start() {
        // Don't start if already running
        if isMitmwebRunning() {
            isRunning = true
            return
        }
        
        launchMitmweb()
        
        // Check status after a short delay to allow mitmweb to start
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.checkStatus()
        }
    }
    
    func stop() {
        killMitmweb()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.checkStatus()
        }
    }
    
    func checkStatus() {
        let running = isMitmwebRunning()
        DispatchQueue.main.async { [weak self] in
            self?.isRunning = running
        }
    }
    
    // MARK: - Private Methods
    
    private func launchMitmweb() {
        // Find mitmweb in common locations
        let possiblePaths = [
            "/opt/homebrew/bin/mitmweb",      // Apple Silicon Homebrew
            "/usr/local/bin/mitmweb",          // Intel Homebrew
            "/usr/bin/mitmweb"
        ]
        
        var mitmwebPath: String?
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                mitmwebPath = path
                break
            }
        }
        
        // Try using `which` as fallback
        if mitmwebPath == nil {
            mitmwebPath = findExecutable("mitmweb")
        }
        
        guard let executablePath = mitmwebPath else {
            print("mitmweb not found. Please install it with: brew install mitmproxy")
            return
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = mitmwebArguments
        
        // Redirect output to /dev/null to avoid blocking
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            mitmwebProcess = process
            print("mitmweb started with PID: \(process.processIdentifier)")
        } catch {
            print("Failed to start mitmweb: \(error)")
        }
    }
    
    private func findExecutable(_ name: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    return path
                }
            }
        } catch {
            // Ignore
        }
        return nil
    }
    
    private func killMitmweb() {
        // First try to terminate our tracked process
        if let process = mitmwebProcess, process.isRunning {
            process.terminate()
            mitmwebProcess = nil
        }
        
        // Also kill any other mitmweb processes
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        process.arguments = ["-f", "mitmweb"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            // Ignore errors - process might not exist
        }
    }
    
    private func isMitmwebRunning() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", "mitmweb"]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}

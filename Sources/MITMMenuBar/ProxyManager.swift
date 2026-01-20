import Foundation
import Combine

class ProxyManager: ObservableObject {
    @Published private(set) var isEnabled: Bool = false
    
    private let proxyHost = "127.0.0.1"
    private let proxyPort = "8080"
    private let networkService = "Wi-Fi"
    
    // MARK: - Public Methods
    
    func enable() {
        // Set HTTP proxy
        runNetworkSetup(["-setwebproxy", networkService, proxyHost, proxyPort])
        // Set HTTPS proxy
        runNetworkSetup(["-setsecurewebproxy", networkService, proxyHost, proxyPort])
        
        // Update status after a short delay to let the system apply changes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkStatus()
        }
    }
    
    func disable() {
        // Disable HTTP proxy
        runNetworkSetup(["-setwebproxystate", networkService, "off"])
        // Disable HTTPS proxy
        runNetworkSetup(["-setsecurewebproxystate", networkService, "off"])
        
        // Update status after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkStatus()
        }
    }
    
    func checkStatus() {
        let output = runNetworkSetupWithOutput(["-getwebproxy", networkService])
        
        // Parse output to check if proxy is enabled
        // Output format:
        // Enabled: Yes/No
        // Server: 127.0.0.1
        // Port: 8080
        // ...
        
        let lines = output.components(separatedBy: "\n")
        var enabled = false
        var server = ""
        var port = ""
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("Enabled:") {
                enabled = trimmed.contains("Yes")
            } else if trimmed.hasPrefix("Server:") {
                server = trimmed.replacingOccurrences(of: "Server:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Port:") {
                port = trimmed.replacingOccurrences(of: "Port:", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
        
        // Only consider enabled if it's our proxy (127.0.0.1:8080)
        let isOurProxy = enabled && server == proxyHost && port == proxyPort
        
        DispatchQueue.main.async { [weak self] in
            self?.isEnabled = isOurProxy
        }
    }
    
    // MARK: - Private Methods
    
    private func runNetworkSetup(_ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        process.arguments = arguments
        
        // Capture stderr for debugging
        let errorPipe = Pipe()
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                if let errorString = String(data: errorData, encoding: .utf8) {
                    print("networksetup error: \(errorString)")
                }
            }
        } catch {
            print("Failed to run networksetup: \(error)")
        }
    }
    
    private func runNetworkSetupWithOutput(_ arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        process.arguments = arguments
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: outputData, encoding: .utf8) ?? ""
        } catch {
            print("Failed to run networksetup: \(error)")
            return ""
        }
    }
}

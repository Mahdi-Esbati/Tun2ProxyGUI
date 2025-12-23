import Foundation
import AppKit

final class AppListenerService {
    static let shared = AppListenerService()
    
    private init() {}
    
    func fetchAppListeners() async -> [AppListener] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        // -n: inhibits the conversion of network numbers to host names for network files
        // -P: inhibits the conversion of port numbers to port names for network files
        // -iTCP: selects the listing of IPv4 and IPv6 TCP files
        // -sTCP:LISTEN: selects the listing of TCP files with state LISTEN
        // -F pcn: field output for PID (p), Command (c), and Name (n - includes address/port)
        p.arguments = ["-nP", "-iTCP", "-sTCP:LISTEN", "-F", "pcn"]
        
        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()
        
        do {
            try p.run()
            let data = out.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            
            guard let output = String(data: data, encoding: .utf8) else { return [] }
            return parseLsofOutput(output)
        } catch {
            print("Failed to run lsof: \(error.localizedDescription)")
            return []
        }
    }
    
    private func parseLsofOutput(_ output: String) -> [AppListener] {
        var listeners: [AppListener] = []
        let lines = output.components(separatedBy: .newlines)
        
        var currentPID: Int32?
        var currentCommand: String?
        
        for line in lines {
            if line.isEmpty { continue }
            
            let prefix = line.prefix(1)
            let value = String(line.dropFirst())
            
            switch prefix {
            case "p":
                currentPID = Int32(value)
            case "c":
                currentCommand = value
            case "n":
                if let pid = currentPID, let port = extractPort(from: value) {
                    // Get app details from NSRunningApplication if possible
                    let (appName, icon) = fetchAppDetails(pid: pid, defaultName: currentCommand ?? value)
                    
                    let listener = AppListener(
                        pid: pid,
                        name: appName,
                        port: port,
                        icon: icon
                    )
                    
                    // Avoid duplicates (multiple listeners for same PID/port)
                    if !listeners.contains(where: { $0.pid == pid && $0.port == port }) {
                        listeners.append(listener)
                    }
                }
            default:
                break
            }
        }
        
        return listeners.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
    
    private func extractPort(from name: String) -> String? {
        // name is usually something like "127.0.0.1:1080" or "*:1080"
        let parts = name.components(separatedBy: ":")
        return parts.last
    }
    
    private func fetchAppDetails(pid: Int32, defaultName: String) -> (String, NSImage?) {
        // 1. Try NSRunningApplication directly
        if let app = NSRunningApplication(processIdentifier: pid) {
            // Check if it's already an app or if it has a bundle URL we can trace
            if let bundleURL = app.bundleURL, let details = findContainingAppDetails(from: bundleURL) {
                return details
            }
            if let executableURL = app.executableURL, let details = findContainingAppDetails(from: executableURL) {
                return details
            }
            return (app.localizedName ?? defaultName, app.icon)
        }
        
        // 2. Fallback: try to get the path via ps and trace it
        if let executableURL = getExecutableURL(for: pid), let details = findContainingAppDetails(from: executableURL) {
            return details
        }
        
        return (defaultName, nil)
    }

    private func getExecutableURL(for pid: Int32) -> URL? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/ps")
        p.arguments = ["-p", "\(pid)", "-o", "comm="]
        
        let out = Pipe()
        p.standardOutput = out
        
        do {
            try p.run()
            let data = out.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty {
                return URL(fileURLWithPath: path)
            }
        } catch {
            return nil
        }
        return nil
    }

    private func findContainingAppDetails(from url: URL) -> (String, NSImage?)? {
        var currentURL = url.resolvingSymlinksInPath()
        
        // Walk up from the current path to find a .app bundle
        while currentURL.path != "/" {
            if currentURL.pathExtension == "app" {
                if let bundle = Bundle(url: currentURL) {
                    let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                        ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                        ?? currentURL.deletingPathExtension().lastPathComponent
                    
                    let icon = NSWorkspace.shared.icon(forFile: currentURL.path)
                    return (name, icon)
                }
            }
            currentURL = currentURL.deletingLastPathComponent()
        }
        return nil
    }
}


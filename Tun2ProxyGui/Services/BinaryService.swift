import Foundation
import AppKit

final class BinaryService {
    static let shared = BinaryService()
    
    private init() {}
    
    func bundledTun2ProxyPath() -> String? {
        if let p = Bundle.main.path(forResource: "tun2proxy-bin", ofType: nil),
           FileManager.default.fileExists(atPath: p) {
            return p
        }
        return nil
    }
    
    func checkAuthorization(path: String) -> Bool {
        let resolvedPath = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
        guard !resolvedPath.isEmpty, FileManager.default.fileExists(atPath: resolvedPath) else {
            return false
        }
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: resolvedPath)
            let ownerID = (attrs[.ownerAccountID] as? NSNumber)?.intValue
            let permissions = (attrs[.posixPermissions] as? NSNumber)?.intValue ?? 0
            // Check for root owner (0) and setuid bit (0o4000)
            return ownerID == 0 && (permissions & 0o4000) != 0
        } catch {
            return false
        }
    }
    
    func authorizeBinary(path: String) async throws -> Bool {
        let resolvedPath = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
        guard !resolvedPath.isEmpty, FileManager.default.fileExists(atPath: resolvedPath) else {
            throw NSError(domain: "BinaryService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Binary not found at \(path)"])
        }

        let shellCommand = "chown root \"\(resolvedPath)\" && chmod u+s \"\(resolvedPath)\""
        
        let escapedForAppleScript = shellCommand
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = "do shell script \"\(escapedForAppleScript)\" with administrator privileges"

        return try await withCheckedThrowingContinuation { continuation in
            let appleScript = NSAppleScript(source: script)
            var error: NSDictionary?
            let _ = appleScript?.executeAndReturnError(&error)

            if let err = error {
                let msg = err["NSAppleScriptErrorMessage"] as? String ?? "Unknown error"
                continuation.resume(throwing: NSError(domain: "BinaryService", code: 2, userInfo: [NSLocalizedDescriptionKey: msg]))
            } else {
                continuation.resume(returning: true)
            }
        }
    }
    
    func autoDetectBinary(appendLog: @escaping (String) -> Void) -> String? {
        if let bundled = bundledTun2ProxyPath() {
            appendLog("Auto-detect: using bundled binary: \(bundled)")
            return bundled
        } else {
            appendLog("Auto-detect: bundled binary not found.")
        }

        let candidates = [
            "/opt/homebrew/bin/tun2proxy-bin",
            "/usr/local/bin/tun2proxy-bin",
            "/opt/homebrew/bin/tun2proxy",
            "/usr/local/bin/tun2proxy"
        ]

        appendLog("Auto-detect: checking common system paths…")

        for path in candidates {
            guard FileManager.default.fileExists(atPath: path) else {
                appendLog(" - not found: \(path)")
                continue
            }

            let resolvedPath = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
            appendLog(" - found: \(path)")
            if resolvedPath != path { appendLog("   ↳ resolves to: \(resolvedPath)") }

            appendLog("   ↳ probing launch…")
            if canLaunch(resolvedPath) {
                appendLog("Detected system binary: \(resolvedPath)")
                return resolvedPath
            } else {
                do {
                    let attrs = try FileManager.default.attributesOfItem(atPath: resolvedPath)
                    if let perms = attrs[.posixPermissions] as? NSNumber {
                        appendLog("   ↳ perms: \(String(perms.intValue, radix: 8))")
                    }
                    if let owner = attrs[.ownerAccountName] as? String {
                        appendLog("   ↳ owner: \(owner)")
                    }
                } catch {
                    appendLog("   ↳ could not read attributes: \(error.localizedDescription)")
                }
            }
        }

        appendLog("Auto-detect: PATH lookup via shell…")
        if let found = whichViaShell(["tun2proxy-bin", "tun2proxy"]) {
            appendLog("Detected via shell PATH: \(found)")
            return found
        }

        appendLog("Could not auto-detect tun2proxy. Set the path manually.")
        return nil
    }

    func canLaunch(_ path: String) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = ["--version"]
        p.standardOutput = Pipe()
        p.standardError = Pipe()

        do {
            try p.run()
            p.waitUntilExit()
            return true
        } catch {
            return false
        }
    }

    private func whichViaShell(_ commands: [String]) -> String? {
        for cmd in commands {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/zsh")
            p.arguments = ["-lc", "command -v \(cmd)"]

            let out = Pipe()
            p.standardOutput = out
            p.standardError = Pipe()

            do {
                try p.run()
                p.waitUntilExit()
                guard p.terminationStatus == 0 else { continue }

                let data = out.fileHandleForReading.readDataToEndOfFile()
                let s = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                if !s.isEmpty { return s }
            } catch {
                continue
            }
        }
        return nil
    }
}


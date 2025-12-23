import Foundation
import AppKit
import Combine
import Darwin

@MainActor
final class Tun2ProxyViewModel: ObservableObject {
    enum ProxyType: String, CaseIterable, Identifiable {
        case socks5 = "socks5"
        case socks5h = "socks5h"
        case socks4 = "socks4"
        case socks4a = "socks4a"
        case http = "http"
        case https = "https"

        var id: String { self.rawValue }
        var description: String {
            switch self {
            case .socks5: return "SOCKS5"
            case .socks5h: return "SOCKS5h"
            case .socks4: return "SOCKS4"
            case .socks4a: return "SOCKS4a"
            case .http: return "HTTP"
            case .https: return "HTTPS"
            }
        }
    }

    struct LogEntry: Identifiable, Equatable {
        let id = UUID()
        let timestamp = Date()
        let message: String
        let type: LogType

        enum LogType: String {
            case stdout = "stdout"
            case stderr = "stderr"
            case info = "info"
        }
    }

    @Published var proxyURL: String = "socks5://localhost:1080"
    @Published var proxyType: ProxyType = .socks5
    @Published var proxyHost: String = "localhost"
    @Published var proxyPort: String = "1080"
    @Published var proxyUsername: String = ""
    @Published var proxyPassword: String = ""

    /// Path shown in UI. We default it to the bundled binary if available.
    @Published var binaryPath: String = ""

    @Published var logEntries: [LogEntry] = []
    @Published var isRunning: Bool = false
    @Published var isAuthorized: Bool = false

    private var process: Process?
    private var outPipe: Pipe?
    private var errPipe: Pipe?
    private var lastError: String = ""
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Prefer bundled binary on launch.
        if let bundled = bundledTun2ProxyPath() {
            binaryPath = bundled
        } else {
            // Fallback (dev convenience)
            binaryPath = "/opt/homebrew/bin/tun2proxy-bin"
        }
        checkAuthorization()

        // Sync URL parts to proxyURL
        Publishers.CombineLatest(
            Publishers.CombineLatest3($proxyType, $proxyHost, $proxyPort),
            Publishers.CombineLatest($proxyUsername, $proxyPassword)
        )
        .map { (params1, params2) -> String in
            let (type, host, port) = params1
            let (user, pass) = params2
            var url = "\(type.rawValue)://"
            if !user.isEmpty {
                url += user
                if !pass.isEmpty {
                    url += ":\(pass)"
                }
                url += "@"
            }
            url += host
            if !port.isEmpty {
                url += ":\(port)"
            }
            return url
        }
        .assign(to: &$proxyURL)

        $binaryPath
            .sink { [weak self] _ in
                self?.checkAuthorization()
            }
            .store(in: &cancellables)
    }

    func checkAuthorization() {
        let resolvedPath = URL(fileURLWithPath: binaryPath).resolvingSymlinksInPath().path
        guard !resolvedPath.isEmpty, FileManager.default.fileExists(atPath: resolvedPath) else {
            isAuthorized = false
            return
        }
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: resolvedPath)
            let ownerID = (attrs[.ownerAccountID] as? NSNumber)?.intValue
            let permissions = (attrs[.posixPermissions] as? NSNumber)?.intValue ?? 0
            // Check for root owner (0) and setuid bit (0o4000)
            isAuthorized = ownerID == 0 && (permissions & 0o4000) != 0
        } catch {
            isAuthorized = false
        }
    }

    func appendLog(_ message: String, type: LogEntry.LogType = .info) {
        let cleanMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanMessage.isEmpty else { return }
        
        // Split by lines if multiple lines are provided
        let lines = cleanMessage.components(separatedBy: .newlines)
        for line in lines where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            logEntries.append(LogEntry(message: line, type: type))
        }
    }

    func clearLogs() { logEntries = [] }

    // MARK: - Bundled executable

    /// Looks for `tun2proxy-bin` bundled in the app.
    /// This requires that the file is included in *Copy Bundle Resources* (or equivalent).
    private func bundledTun2ProxyPath() -> String? {
        // Try Resources first (common if you added it to Copy Bundle Resources).
        if let p = Bundle.main.path(forResource: "tun2proxy-bin", ofType: nil),
           FileManager.default.fileExists(atPath: p) {
            return p
        }

        // If you ever move it to a subfolder in Resources, add another lookup here.
        return nil
    }

    // MARK: - Auto-detect

    /// Auto-detect now prefers the bundled binary and only falls back to system paths.
    func autoDetectBinary() {
        if let bundled = bundledTun2ProxyPath() {
            binaryPath = bundled
            appendLog("Auto-detect: using bundled binary: \(bundled)")
            checkAuthorization()
            return
        } else {
            appendLog("Auto-detect: bundled binary not found. (Make sure tun2proxy-bin is in Copy Bundle Resources.)")
        }

        // Fallback to system installs (optional)
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
                binaryPath = resolvedPath
                appendLog("Detected system binary: \(resolvedPath)")
                checkAuthorization()
                return
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
            binaryPath = found
            appendLog("Detected via shell PATH: \(found)")
            checkAuthorization()
            return
        }

        appendLog("Could not auto-detect tun2proxy. Set the path manually.")
        checkAuthorization()
    }

    private func canLaunch(_ path: String) -> Bool {
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
            appendLog("   ↳ launch probe failed: \(error.localizedDescription)")
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

    // MARK: - Actions

    func testBinary() {
        runOneShot(args: ["--help"], title: "Testing binary")
    }

    func copySetupCommand() {
        let cmd = "sudo \"\(binaryPath)\" --setup"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(cmd, forType: .string)
        appendLog("Copied setup command to clipboard:\n\(cmd)\nRun it once in Terminal.")
    }

    func authorizeBinary() {
        let resolvedPath = URL(fileURLWithPath: binaryPath).resolvingSymlinksInPath().path
        guard !resolvedPath.isEmpty, FileManager.default.fileExists(atPath: resolvedPath) else {
            appendLog("Authorization failed: Binary not found at \(binaryPath)")
            return
        }

        let shellCommand = "chown root \"\(resolvedPath)\" && chmod u+s \"\(resolvedPath)\""
        
        // Escaping for AppleScript string literal: escape backslashes and double quotes
        let escapedForAppleScript = shellCommand
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = "do shell script \"\(escapedForAppleScript)\" with administrator privileges"

        appendLog("Requesting administrator privileges to authorize binary...")

        Task.detached {
            let appleScript = NSAppleScript(source: script)
            var error: NSDictionary?
            let _ = appleScript?.executeAndReturnError(&error)

            await MainActor.run {
                if let err = error {
                    let msg = err["NSAppleScriptErrorMessage"] as? String ?? "Unknown error"
                    self.appendLog("Authorization failed: \(msg)")
                } else {
                    self.appendLog("Authorization successful! Binary is now setuid root.")
                    self.checkAuthorization()
                }
            }
        }
    }

    func start() {
        checkAuthorization()
        if isAuthorized {
            appendLog("Auth check: OK (root/setuid).")
        } else {
            appendLog("Auth check: Not authorized.")
            let resolved = URL(fileURLWithPath: binaryPath).resolvingSymlinksInPath().path
            appendLog(" ↳ Binary: \(resolved)")
        }
        startInternal(useSudo: false)
    }

    private func startInternal(useSudo: Bool) {
        guard process == nil else { return }

        guard FileManager.default.fileExists(atPath: binaryPath) else {
            appendLog("Error: binary not found at \(binaryPath)")
            return
        }

        var args = [
            "--proxy", proxyURL,
            "--dns", "virtual",
            "--setup"
        ]

        if useSudo {
            args.append("--daemonize")
            runWithSudo(args: args)
            return
        }

        // First attempt: run without --daemonize to catch "Operation not permitted"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: binaryPath)
        p.arguments = args

        let out = Pipe()
        let err = Pipe()
        p.standardOutput = out
        p.standardError = err

        outPipe = out
        errPipe = err

        lastError = ""
        stream(pipe: out, label: "stdout")
        stream(pipe: err, label: "stderr")

        do {
            try p.run()
            process = p
            isRunning = true
            appendLog("Started: \(binaryPath) \(args.joined(separator: " "))")

            p.terminationHandler = { [weak self] proc in
                Task { @MainActor in
                    let status = proc.terminationStatus
                    self?.appendLog("Process exited with code \(status)")
                    
                    if status != 0 && self?.lastError.contains("Operation not permitted") == true {
                        self?.appendLog("Detected 'Operation not permitted'. Retrying with administrator privileges...")
                        self?.cleanupAfterStop()
                        self?.startInternal(useSudo: true)
                    } else {
                        self?.cleanupAfterStop()
                    }
                }
            }
        } catch {
            appendLog("Failed to start process: \(error.localizedDescription)")
            cleanupAfterStop()
        }
    }

    private func runWithSudo(args: [String]) {
        // Escaping for 'sh' (used by 'do shell script'): wrap in single quotes,
        // and replace any existing single quotes with '\''
        let escapeForSh = { (s: String) -> String in
            let escaped = s.replacingOccurrences(of: "'", with: "'\\''")
            return "'\(escaped)'"
        }

        let binaryEscaped = escapeForSh(binaryPath)
        let argsEscaped = args.map(escapeForSh).joined(separator: " ")
        let fullShellCommand = "\(binaryEscaped) \(argsEscaped)"

        // Escaping for AppleScript string literal: escape backslashes and double quotes
        let escapedForAppleScript = fullShellCommand
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = "do shell script \"\(escapedForAppleScript)\" with administrator privileges"

        appendLog("Requesting administrator privileges via AppleScript...")

        Task.detached {
            let appleScript = NSAppleScript(source: script)
            var error: NSDictionary?
            let _ = appleScript?.executeAndReturnError(&error)

            await MainActor.run {
                if let err = error {
                    let msg = err["NSAppleScriptErrorMessage"] as? String ?? "Unknown AppleScript error"
                    self.appendLog("Elevation failed: \(msg)")
                    self.cleanupAfterStop()
                } else {
                    self.appendLog("Elevation succeeded. Daemonized process should be running.")
                    self.isRunning = true
                }
            }
        }
    }

    func stop() {
        appendLog("Stopping…")
        stopSync()
    }

    func stopSync() {
        if let p = process {
            let pid = p.processIdentifier
            p.terminate()

            // For synchronous stop (e.g. on termination), we might not want to wait too long.
            // But we can try a quick check if it's still running.
            if p.isRunning {
                // We can't easily wait synchronously here without blocking the main thread
                // which might be bad during termination.
                // But we can at least send a SIGKILL if terminate didn't work immediately.
                // However, terminate() is usually enough for a graceful shutdown.
            }
        } else if isRunning {
            // Probably daemonized
            killDaemonSync()
        }
    }

    private func killDaemonSync() {
        let name = URL(fileURLWithPath: binaryPath).lastPathComponent
        
        // We use a simple Process call to killall instead of AppleScript if we want it synchronous
        // and without user interaction during shutdown.
        // If it was started with sudo, this might fail unless we are root.
        // But if the binary is setuid root, killall might still work if we have permissions? 
        // Actually, killall usually needs to match the user.
        
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        p.arguments = ["-9", name]
        try? p.run()
        p.waitUntilExit()
        
        // Even if it fails, we've tried our best.
        cleanupAfterStop()
    }

    private func killDaemon() {
        let name = URL(fileURLWithPath: binaryPath).lastPathComponent

        // Use killall -9 as it's very reliable on macOS for name-based termination
        let script = "do shell script \"killall -9 '\(name)'\" with administrator privileges"

        appendLog("Requesting administrator privileges to stop daemon (\(name))...")

        Task.detached {
            let appleScript = NSAppleScript(source: script)
            var error: NSDictionary?
            let _ = appleScript?.executeAndReturnError(&error)

            await MainActor.run {
                if let err = error {
                    let msg = err["NSAppleScriptErrorMessage"] as? String ?? ""
                    if msg.contains("No matching processes") {
                        self.appendLog("Daemon was already stopped.")
                    } else {
                        self.appendLog("Stop command finished (might have failed: \(msg))")
                    }
                } else {
                    self.appendLog("Daemon terminated.")
                }
                self.cleanupAfterStop()
            }
        }
    }

    // MARK: - helpers

    private func cleanupAfterStop() {
        outPipe?.fileHandleForReading.readabilityHandler = nil
        errPipe?.fileHandleForReading.readabilityHandler = nil
        outPipe = nil
        errPipe = nil

        process = nil
        isRunning = false
    }

    private func stream(pipe: Pipe, label: String) {
        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { [weak self] h in
            let data = h.availableData
            guard !data.isEmpty else { return }
            guard let str = String(data: data, encoding: .utf8), !str.isEmpty else { return }
            DispatchQueue.main.async {
                let type: LogEntry.LogType = (label == "stdout") ? .stdout : .stderr
                self?.appendLog(str, type: type)
                if label == "stderr" {
                    self?.lastError += str
                }
            }
        }
    }

    private func runOneShot(args: [String], title: String) {
        appendLog("\(title)…", type: .info)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: binaryPath)
        p.arguments = args
        let out = Pipe()
        let err = Pipe()
        p.standardOutput = out
        p.standardError = err
        do {
            try p.run()
            p.waitUntilExit()

            let o = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let e = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            if !o.isEmpty { appendLog(o, type: .stdout) }
            if !e.isEmpty { appendLog(e, type: .stderr) }
            appendLog("Exit code: \(p.terminationStatus)", type: .info)
        } catch {
            appendLog("One-shot failed: \(error.localizedDescription)", type: .stderr)
        }
    }

    var fullLogs: String {
        logEntries.map { "[\($0.timestamp)] [\($0.type.rawValue)] \($0.message)" }.joined(separator: "\n")
    }

    // Keeping this in case you want it elsewhere, but PATH in GUI apps is usually different.
    private func which(_ commands: [String]) -> String? {
        for cmd in commands {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            p.arguments = [cmd]
            let out = Pipe()
            p.standardOutput = out
            p.standardError = Pipe()
            do {
                try p.run()
                p.waitUntilExit()
                guard p.terminationStatus == 0 else { continue }
                let data = out.fileHandleForReading.readDataToEndOfFile()
                if let s = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !s.isEmpty {
                    return s
                }
            } catch {
                continue
            }
        }
        return nil
    }
}

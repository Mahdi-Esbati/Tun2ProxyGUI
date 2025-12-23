import Foundation
import AppKit

final class ProxyService {
    static let shared = ProxyService()
    
    private var process: Process?
    private var outPipe: Pipe?
    private var errPipe: Pipe?
    private var lastError: String = ""
    
    private init() {}
    
    func start(binaryPath: String, proxyURL: String, onLog: @escaping (String, LogEntry.LogType) -> Void, onStateChange: @escaping (Bool) -> Void) {
        startInternal(binaryPath: binaryPath, proxyURL: proxyURL, useSudo: false, onLog: onLog, onStateChange: onStateChange)
    }
    
    private func startInternal(binaryPath: String, proxyURL: String, useSudo: Bool, onLog: @escaping (String, LogEntry.LogType) -> Void, onStateChange: @escaping (Bool) -> Void) {
        guard process == nil else { return }

        guard FileManager.default.fileExists(atPath: binaryPath) else {
            onLog("Error: binary not found at \(binaryPath)", .stderr)
            return
        }

        var args = [
            "--proxy", proxyURL,
            "--dns", "virtual",
            "--setup"
        ]

        if useSudo {
            args.append("--daemonize")
            runWithSudo(binaryPath: binaryPath, args: args, onLog: onLog, onStateChange: onStateChange)
            return
        }

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
        stream(pipe: out, label: "stdout", onLog: onLog)
        stream(pipe: err, label: "stderr", onLog: onLog)

        do {
            try p.run()
            process = p
            onStateChange(true)
            onLog("Started: \(binaryPath) \(args.joined(separator: " "))", .info)

            p.terminationHandler = { [weak self] proc in
                let status = proc.terminationStatus
                onLog("Process exited with code \(status)", .info)
                
                if status != 0 && self?.lastError.contains("Operation not permitted") == true {
                    onLog("Detected 'Operation not permitted'. Retrying with administrator privileges...", .info)
                    self?.cleanupAfterStop(onStateChange: onStateChange)
                    self?.startInternal(binaryPath: binaryPath, proxyURL: proxyURL, useSudo: true, onLog: onLog, onStateChange: onStateChange)
                } else {
                    self?.cleanupAfterStop(onStateChange: onStateChange)
                }
            }
        } catch {
            onLog("Failed to start process: \(error.localizedDescription)", .stderr)
            cleanupAfterStop(onStateChange: onStateChange)
        }
    }

    private func runWithSudo(binaryPath: String, args: [String], onLog: @escaping (String, LogEntry.LogType) -> Void, onStateChange: @escaping (Bool) -> Void) {
        let escapeForSh = { (s: String) -> String in
            let escaped = s.replacingOccurrences(of: "'", with: "'\\''")
            return "'\(escaped)'"
        }

        let binaryEscaped = escapeForSh(binaryPath)
        let argsEscaped = args.map(escapeForSh).joined(separator: " ")
        let fullShellCommand = "\(binaryEscaped) \(argsEscaped)"

        let escapedForAppleScript = fullShellCommand
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = "do shell script \"\(escapedForAppleScript)\" with administrator privileges"

        onLog("Requesting administrator privileges via AppleScript...", .info)

        Task.detached {
            let appleScript = NSAppleScript(source: script)
            var error: NSDictionary?
            let _ = appleScript?.executeAndReturnError(&error)

            if let err = error {
                let msg = err["NSAppleScriptErrorMessage"] as? String ?? "Unknown AppleScript error"
                onLog("Elevation failed: \(msg)", .stderr)
                await MainActor.run {
                    self.cleanupAfterStop(onStateChange: onStateChange)
                }
            } else {
                onLog("Elevation succeeded. Daemonized process should be running.", .info)
                await MainActor.run {
                    onStateChange(true)
                }
            }
        }
    }

    func stop(binaryPath: String, isRunning: Bool, onLog: @escaping (String, LogEntry.LogType) -> Void, onStateChange: @escaping (Bool) -> Void) {
        onLog("Stopping…", .info)
        stopSync(binaryPath: binaryPath, isRunning: isRunning, onStateChange: onStateChange)
    }

    func stopSync(binaryPath: String, isRunning: Bool, onStateChange: @escaping (Bool) -> Void) {
        if let p = process {
            p.terminate()
        } else if isRunning {
            killDaemonSync(binaryPath: binaryPath, onStateChange: onStateChange)
        }
    }

    private func killDaemonSync(binaryPath: String, onStateChange: @escaping (Bool) -> Void) {
        let name = URL(fileURLWithPath: binaryPath).lastPathComponent
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        p.arguments = ["-9", name]
        try? p.run()
        p.waitUntilExit()
        cleanupAfterStop(onStateChange: onStateChange)
    }

    func killDaemon(binaryPath: String, onLog: @escaping (String, LogEntry.LogType) -> Void, onStateChange: @escaping (Bool) -> Void) {
        let name = URL(fileURLWithPath: binaryPath).lastPathComponent
        let script = "do shell script \"killall -9 '\(name)'\" with administrator privileges"

        onLog("Requesting administrator privileges to stop daemon (\(name))...", .info)

        Task.detached {
            let appleScript = NSAppleScript(source: script)
            var error: NSDictionary?
            let _ = appleScript?.executeAndReturnError(&error)

            if let err = error {
                let msg = err["NSAppleScriptErrorMessage"] as? String ?? ""
                if msg.contains("No matching processes") {
                    onLog("Daemon was already stopped.", .info)
                } else {
                    onLog("Stop command finished (might have failed: \(msg))", .info)
                }
            } else {
                onLog("Daemon terminated.", .info)
            }
            await MainActor.run {
                self.cleanupAfterStop(onStateChange: onStateChange)
            }
        }
    }

    private func cleanupAfterStop(onStateChange: @escaping (Bool) -> Void) {
        outPipe?.fileHandleForReading.readabilityHandler = nil
        errPipe?.fileHandleForReading.readabilityHandler = nil
        outPipe = nil
        errPipe = nil

        process = nil
        onStateChange(false)
    }

    private func stream(pipe: Pipe, label: String, onLog: @escaping (String, LogEntry.LogType) -> Void) {
        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { [weak self] h in
            let data = h.availableData
            guard !data.isEmpty else { return }
            guard let str = String(data: data, encoding: .utf8), !str.isEmpty else { return }
            
            let type: LogEntry.LogType = (label == "stdout") ? .stdout : .stderr
            onLog(str, type)
            if label == "stderr" {
                self?.lastError += str
            }
        }
    }

    func runOneShot(binaryPath: String, args: [String], title: String, onLog: @escaping (String, LogEntry.LogType) -> Void) {
        onLog("\(title)…", .info)
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
            if !o.isEmpty { onLog(o, .stdout) }
            if !e.isEmpty { onLog(e, .stderr) }
            onLog("Exit code: \(p.terminationStatus)", .info)
        } catch {
            onLog("One-shot failed: \(error.localizedDescription)", .stderr)
        }
    }
}


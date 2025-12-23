import Foundation
import AppKit
import Combine

@MainActor
final class Tun2ProxyViewModel: ObservableObject {
    @Published var proxyURL: String = "socks5://localhost:1080"
    @Published var proxyType: ProxyType = .socks5
    @Published var proxyHost: String = "localhost"
    @Published var proxyPort: String = "1080"
    @Published var proxyUsername: String = ""
    @Published var proxyPassword: String = ""

    @Published var binaryPath: String = ""
    @Published var logEntries: [LogEntry] = []
    @Published var isRunning: Bool = false
    @Published var isAuthorized: Bool = false
    
    @Published var appListeners: [AppListener] = []
    @Published var isScanning: Bool = false
    @Published var selectedTabIndex: Int = 0

    private var cancellables = Set<AnyCancellable>()
    private let binaryService = BinaryService.shared
    private let proxyService = ProxyService.shared
    private let appListenerService = AppListenerService.shared

    init() {
        if let bundled = binaryService.bundledTun2ProxyPath() {
            binaryPath = bundled
        } else {
            binaryPath = "/opt/homebrew/bin/tun2proxy-bin"
        }
        checkAuthorization()

        setupUrlSync()

        $binaryPath
            .sink { [weak self] _ in
                self?.checkAuthorization()
            }
            .store(in: &cancellables)
    }

    private func setupUrlSync() {
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
    }

    func checkAuthorization() {
        isAuthorized = binaryService.checkAuthorization(path: binaryPath)
    }

    func appendLog(_ message: String, type: LogEntry.LogType = .info) {
        let cleanMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanMessage.isEmpty else { return }
        
        let lines = cleanMessage.components(separatedBy: .newlines)
        for line in lines where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            logEntries.append(LogEntry(message: line, type: type))
        }
    }

    func clearLogs() { logEntries = [] }

    func autoDetectBinary() {
        if let detected = binaryService.autoDetectBinary(appendLog: { [weak self] msg in
            self?.appendLog(msg)
        }) {
            binaryPath = detected
            checkAuthorization()
        }
    }

    func testBinary() {
        proxyService.runOneShot(binaryPath: binaryPath, args: ["--help"], title: "Testing binary") { [weak self] msg, type in
            Task { @MainActor in
                self?.appendLog(msg, type: type)
            }
        }
    }

    func copySetupCommand() {
        let cmd = "sudo \"\(binaryPath)\" --setup"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(cmd, forType: .string)
        appendLog("Copied setup command to clipboard:\n\(cmd)\nRun it once in Terminal.")
    }

    func authorizeBinary() {
        Task {
            do {
                let success = try await binaryService.authorizeBinary(path: binaryPath)
                if success {
                    appendLog("Authorization successful! Binary is now setuid root.")
                    checkAuthorization()
                }
            } catch {
                appendLog("Authorization failed: \(error.localizedDescription)")
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
        
        proxyService.start(binaryPath: binaryPath, proxyURL: proxyURL, onLog: { [weak self] msg, type in
            Task { @MainActor in
                self?.appendLog(msg, type: type)
            }
        }, onStateChange: { [weak self] isRunning in
            Task { @MainActor in
                self?.isRunning = isRunning
            }
        })
    }

    func stop() {
        proxyService.stop(binaryPath: binaryPath, isRunning: isRunning, onLog: { [weak self] msg, type in
            Task { @MainActor in
                self?.appendLog(msg, type: type)
            }
        }, onStateChange: { [weak self] isRunning in
            Task { @MainActor in
                self?.isRunning = isRunning
            }
        })
    }

    func stopSync() {
        proxyService.stopSync(binaryPath: binaryPath, isRunning: isRunning, onStateChange: { [weak self] isRunning in
            self?.isRunning = isRunning
        })
    }

    func fetchAppListeners() {
        isScanning = true
        Task {
            let listeners = await appListenerService.fetchAppListeners()
            await MainActor.run {
                self.appListeners = listeners
                self.isScanning = false
            }
        }
    }

    func selectAppListener(_ listener: AppListener) {
        self.proxyHost = "localhost"
        self.proxyPort = listener.port
        self.selectedTabIndex = 0 // Switch back to Status tab
    }

    var fullLogs: String {
        logEntries.map { "[\($0.timestamp)] [\($0.type.rawValue)] \($0.message)" }.joined(separator: "\n")
    }
}


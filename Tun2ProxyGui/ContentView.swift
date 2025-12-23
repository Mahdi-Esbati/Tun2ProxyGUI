import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var vm: Tun2ProxyViewModel

    private var statusText: String { vm.isRunning ? "Connected" : "Disconnected" }
    private var statusIcon: String { vm.isRunning ? "checkmark.circle.fill" : "xmark.circle.fill" }
    private var statusColor: Color { vm.isRunning ? .green : .red }

    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            VisualEffectView()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Shared Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tun2Proxy")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.primary, .primary.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    Spacer()

                    StatusPill(text: statusText, systemImage: statusIcon, color: statusColor, isPulseActive: vm.isRunning)
                        .transition(.scale.combined(with: .opacity))
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 12)

                TabView(selection: $selectedTab) {
                    StatusTabView()
                        .tabItem {
                            Label("Status", systemImage: "bolt.fill")
                        }
                        .tag(0)

                    LogsTabView()
                        .tabItem {
                            Label("Logs", systemImage: "terminal.fill")
                        }
                        .tag(1)
                }
                .tabViewStyle(.automatic)
            }
        }
        .frame(width: 480, height: 680)
        .contentShape(Rectangle())
    }
}

// MARK: - Tab Views
// ... (rest of the file remains the same until LiquidBackground)

private struct StatusTabView: View {
    @EnvironmentObject var vm: Tun2ProxyViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Proxy
                SectionCard(
                    title: "Proxy",
                    subtitle: "Endpoint settings for tun2proxy",
                    systemImage: "arrow.triangle.branch"
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Type")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Picker("", selection: $vm.proxyType) {
                                    ForEach(Tun2ProxyViewModel.ProxyType.allCases) { type in
                                        Text(type.description).tag(type)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 100)
                            }

                            LabeledField(
                                label: "Host",
                                placeholder: "localhost",
                                text: $vm.proxyHost
                            )
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Port")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                TextField("1080", text: $vm.proxyPort)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 70)
                            }
                        }

                        HStack(spacing: 12) {
                            LabeledField(
                                label: "Username (optional)",
                                placeholder: "user",
                                text: $vm.proxyUsername
                            )
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Password (optional)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                SecureField("pass", text: $vm.proxyPassword)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Full URL")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(vm.proxyURL)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.primary.opacity(0.8))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                                        }
                                }
                        }

                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                            Text("Tip: use localhost to avoid IPv6 bracket parsing issues.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Binary
                SectionCard(
                    title: "Binary",
                    subtitle: "Path to tun2proxy executable",
                    systemImage: "terminal"
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledField(
                            label: "Executable Path",
                            placeholder: "/opt/homebrew/bin/tun2proxy-bin",
                            text: $vm.binaryPath
                        )

                        HStack(spacing: 8) {
                            Button {
                                withAnimation(.spring()) {
                                    vm.autoDetectBinary()
                                }
                            } label: {
                                Label("Auto-detect", systemImage: "magnifyingglass")
                            }
                            .buttonStyle(.bordered)

                            Button {
                                withAnimation(.spring()) {
                                    vm.testBinary()
                                }
                            } label: {
                                Label("Test", systemImage: "checkmark.seal")
                            }
                            .buttonStyle(.bordered)

                            Spacer()
                        }
                    }
                }

                // Actions
                HStack(spacing: 12) {
                    Button {
                        vm.copySetupCommand()
                    } label: {
                        Label("Setup", systemImage: "wrench.and.screwdriver")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .help("Copies a one-time sudo setup command to your clipboard.")

                    Button {
                        vm.authorizeBinary()
                    } label: {
                        Label(vm.isAuthorized ? "Authorized" : "Authorize", systemImage: vm.isAuthorized ? "lock.open.fill" : "lock.fill")
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(vm.isAuthorized ? .secondary : .primary)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .help("Authorizes the binary to run as root without password prompts.")
                    .disabled(vm.isAuthorized)

                    if vm.isRunning {
                        Button(role: .destructive) {
                            withAnimation(.spring()) {
                                vm.stop()
                            }
                        } label: {
                            Label("Disconnect", systemImage: "stop.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .keyboardShortcut(.defaultAction)
                    } else {
                        Button {
                            withAnimation(.spring()) {
                                vm.start()
                            }
                        } label: {
                            Label("Connect", systemImage: "play.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .keyboardShortcut(.defaultAction)
                        .tint(.accentColor)
                    }
                }
                .padding(.top, 4)

                // Quick Quit (Optional, since we have space now)
                Button(role: .destructive) {
                    vm.stopSync()
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit Application", systemImage: "power")
                        .foregroundStyle(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
        }
    }
}

private struct LogsTabView: View {
    @EnvironmentObject var vm: Tun2ProxyViewModel

    var body: some View {
        VStack(spacing: 16) {
            SectionCard(
                title: "Process Logs",
                subtitle: "Real-time output from tun2proxy",
                systemImage: "text.alignleft"
            ) {
                VStack(alignment: .leading) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                if vm.logEntries.isEmpty {
                                    Text("No logs yet.")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                } else {
                                    ForEach(vm.logEntries) { entry in
                                        LogEntryRow(entry: entry)
                                            .id(entry.id)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: .infinity)
                        .background(Color.black.opacity(0.15))
                        .cornerRadius(12)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(.white.opacity(0.05), lineWidth: 0.5)
                        }
                        .onChange(of: vm.logEntries) { entries in
                            if let last = entries.last {
                                withAnimation {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            withAnimation { vm.clearLogs() }
                        } label: {
                            Label("Clear Logs", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            let panel = NSSavePanel()
                            panel.allowedContentTypes = [.text]
                            panel.nameFieldStringValue = "tun2proxy_logs.txt"
                            if panel.runModal() == .OK, let url = panel.url {
                                try? vm.fullLogs.write(to: url, atomically: true, encoding: .utf8)
                            }
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                        .disabled(vm.logEntries.isEmpty)
                    }
                }
            }
        }
        .padding(24)
    }
}

private struct LogEntryRow: View {
    let entry: Tun2ProxyViewModel.LogEntry
    @State private var isHovered = false

    private var typeColor: Color {
        switch entry.type {
        case .stdout: return .green
        case .stderr: return .red
        case .info: return .blue
        }
    }

    private var timestampString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: entry.timestamp)
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center, spacing: 8) {
                Text(timestampString)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary.opacity(0.6))
                
                Text(entry.type.rawValue.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(typeColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(typeColor.opacity(0.15))
                    .clipShape(Capsule())

                Spacer()
                
                if isHovered {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(entry.message, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Text(entry.message)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.9))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
        .background {
            Rectangle()
                .fill(.white.opacity(isHovered ? 0.08 : 0.03))
                .overlay {
                    Rectangle()
                    .strokeBorder(typeColor.opacity(isHovered ? 0.3 : 0.1), lineWidth: 1)
                }
        }
        // .padding(.horizontal, 8)
        // .padding(.vertical, 2)
        .onHover { hovering in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
    }
}



// MARK: - Small UI Components

private struct StatusPill: View {
    let text: String
    let systemImage: String
    let color: Color
    let isPulseActive: Bool

    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
                .symbolEffect(.pulse, isActive: isPulseActive)
            Text(text)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(color.opacity(0.12))
                .overlay {
                    if isPulseActive {
                        Capsule()
                            .fill(color.opacity(isPulsing ? 0.25 : 0))
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isPulsing)
                    }
                }
                .overlay {
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.5), .clear, .white.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
        }
        .overlay(
            Capsule().strokeBorder(color.opacity(0.25), lineWidth: 1)
        )
        .onAppear {
            if isPulseActive {
                isPulsing = true
            }
        }
        .onChange(of: isPulseActive) { newValue in
            withAnimation {
                isPulsing = newValue
            }
        }
    }
}

private struct SectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    @ViewBuilder var content: Content

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isHovered ? .primary : .secondary)
                    .frame(width: 20, height: 20)
                    .background {
                        if isHovered {
                            Circle()
                                .fill(Color.accentColor.opacity(0.15))
                                .blur(radius: 4)
                        }
                    }
                    .scaleEffect(isHovered ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(isHovered ? Color.primary : Color.primary.opacity(0.9))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            content
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    if isHovered {
                        LinearGradient(
                            colors: [.white.opacity(0.1), .clear, .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(isHovered ? 0.4 : 0.2),
                            .white.opacity(isHovered ? 0.1 : 0.05),
                            .white.opacity(isHovered ? 0.3 : 0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(isHovered ? 0.12 : 0.05), radius: isHovered ? 15 : 5, y: isHovered ? 8 : 2)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

private struct LabeledField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

private struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .sidebar
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

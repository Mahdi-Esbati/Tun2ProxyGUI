import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct LogsTabView: View {
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


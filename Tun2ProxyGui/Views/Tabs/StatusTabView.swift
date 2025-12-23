import SwiftUI

struct StatusTabView: View {
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
                                    ForEach(ProxyType.allCases) { type in
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

                // Quick Quit (Optional)
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


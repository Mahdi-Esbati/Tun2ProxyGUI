import SwiftUI

struct AppsTabView: View {
    @EnvironmentObject var vm: Tun2ProxyViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active Applications")
                        .font(.headline)
                    Text("Select an app to bind tun2proxy to its port")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    vm.fetchAppListeners()
                } label: {
                    if vm.isScanning {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(vm.isScanning)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            if vm.appListeners.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "network.slash")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No active listeners found")
                        .foregroundStyle(.secondary)
                    Button("Scan Again") {
                        vm.fetchAppListeners()
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(vm.appListeners) { listener in
                        HStack(spacing: 12) {
                            if let icon = listener.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 32, height: 32)
                            } else {
                                Image(systemName: "app.dashed")
                                    .font(.system(size: 24))
                                    .frame(width: 32, height: 32)
                                    .foregroundStyle(.secondary)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(listener.name)
                                    .font(.system(.body, design: .rounded).weight(.semibold))
                                Text("Port: \(listener.port) • PID: \(listener.pid)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Select") {
                                withAnimation {
                                    vm.selectAppListener(listener)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .opacity(0.5)
                        }
                        .padding(.bottom, 8)
                    }
                }
                .listStyle(.plain)
                .padding(.horizontal, 16)
            }
        }
        .onAppear {
            if vm.appListeners.isEmpty {
                vm.fetchAppListeners()
            }
        }
    }
}


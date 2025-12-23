import SwiftUI

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


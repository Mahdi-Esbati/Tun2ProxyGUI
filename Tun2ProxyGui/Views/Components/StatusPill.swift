import SwiftUI

struct StatusPill: View {
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


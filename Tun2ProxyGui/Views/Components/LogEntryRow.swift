import SwiftUI
import AppKit

struct LogEntryRow: View {
    let entry: LogEntry
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
        .onHover { hovering in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
    }
}


import Foundation

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


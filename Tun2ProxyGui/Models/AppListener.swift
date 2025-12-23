import Foundation
import AppKit

struct AppListener: Identifiable, Equatable {
    let id = UUID()
    let pid: Int32
    let name: String
    let port: String
    let icon: NSImage?
    
    static func == (lhs: AppListener, rhs: AppListener) -> Bool {
        lhs.pid == rhs.pid && lhs.port == rhs.port
    }
}


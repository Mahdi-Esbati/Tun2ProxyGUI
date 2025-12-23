import Foundation

enum ProxyType: String, CaseIterable, Identifiable {
    case socks5 = "socks5"
    case socks5h = "socks5h"
    case socks4 = "socks4"
    case socks4a = "socks4a"
    case http = "http"
    case https = "https"

    var id: String { self.rawValue }
    var description: String {
        switch self {
        case .socks5: return "SOCKS5"
        case .socks5h: return "SOCKS5h"
        case .socks4: return "SOCKS4"
        case .socks4a: return "SOCKS4a"
        case .http: return "HTTP"
        case .https: return "HTTPS"
        }
    }
}


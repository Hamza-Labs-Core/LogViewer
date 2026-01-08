import Foundation

enum LogSource: Hashable, Sendable, Identifiable {
    case osLog
    case systemLog
    case file(URL)
    case stream
    case systemRestarts

    var id: String {
        switch self {
        case .osLog:
            return "osLog"
        case .systemLog:
            return "systemLog"
        case .file(let url):
            return "file:\(url.path)"
        case .stream:
            return "stream"
        case .systemRestarts:
            return "systemRestarts"
        }
    }

    var displayName: String {
        switch self {
        case .osLog:
            return "App Logs"
        case .systemLog:
            return "System Logs"
        case .file(let url):
            return url.lastPathComponent
        case .stream:
            return "Live Stream"
        case .systemRestarts:
            return "System Restarts"
        }
    }

    var systemImage: String {
        switch self {
        case .osLog:
            return "app.badge"
        case .systemLog:
            return "gearshape.2"
        case .file:
            return "doc.text"
        case .stream:
            return "waveform"
        case .systemRestarts:
            return "bolt.trianglebadge.exclamationmark"
        }
    }
}

import SwiftUI

enum LogLevel: Int, CaseIterable, Comparable, Codable, Sendable {
    case debug = 0
    case info = 1
    case notice = 2
    case warning = 3
    case error = 4
    case fault = 5

    var displayName: String {
        switch self {
        case .debug: return "Debug"
        case .info: return "Info"
        case .notice: return "Notice"
        case .warning: return "Warning"
        case .error: return "Error"
        case .fault: return "Fault"
        }
    }

    var shortName: String {
        switch self {
        case .debug: return "DBG"
        case .info: return "INF"
        case .notice: return "NTC"
        case .warning: return "WRN"
        case .error: return "ERR"
        case .fault: return "FLT"
        }
    }

    var color: Color {
        switch self {
        case .debug: return .secondary
        case .info: return .primary
        case .notice: return .blue
        case .warning: return .orange
        case .error: return .red
        case .fault: return .purple
        }
    }

    var systemImage: String {
        switch self {
        case .debug: return "ant"
        case .info: return "info.circle"
        case .notice: return "bell"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .fault: return "bolt.circle"
        }
    }

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

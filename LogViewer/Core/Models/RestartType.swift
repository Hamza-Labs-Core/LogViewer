import SwiftUI

enum RestartType: String, CaseIterable, Codable, Sendable {
    case kernelPanic
    case watchdog
    case cleanShutdown
    case unexpected

    var displayName: String {
        switch self {
        case .kernelPanic: return "Kernel Panic"
        case .watchdog: return "Watchdog Reset"
        case .cleanShutdown: return "Clean Shutdown"
        case .unexpected: return "Unexpected"
        }
    }

    var shortName: String {
        switch self {
        case .kernelPanic: return "PANIC"
        case .watchdog: return "WDOG"
        case .cleanShutdown: return "CLEAN"
        case .unexpected: return "UNK"
        }
    }

    var color: Color {
        switch self {
        case .kernelPanic: return .red
        case .watchdog: return .orange
        case .cleanShutdown: return .green
        case .unexpected: return .yellow
        }
    }

    var systemImage: String {
        switch self {
        case .kernelPanic: return "bolt.trianglebadge.exclamationmark"
        case .watchdog: return "timer"
        case .cleanShutdown: return "power"
        case .unexpected: return "questionmark.circle"
        }
    }
}

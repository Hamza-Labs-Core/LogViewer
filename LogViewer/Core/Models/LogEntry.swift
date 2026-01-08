import Foundation
import OSLog

struct LogEntry: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let subsystem: String
    let category: String
    let process: String
    let processIdentifier: Int32
    let threadIdentifier: UInt64
    let message: String
    let composedMessage: String
    let activityIdentifier: UInt64
    let source: LogSourceType

    enum LogSourceType: String, Codable, Sendable {
        case osLog
        case systemLog
        case file
        case stream
    }

    init(
        id: UUID = UUID(),
        timestamp: Date,
        level: LogLevel,
        subsystem: String = "",
        category: String = "",
        process: String = "",
        processIdentifier: Int32 = 0,
        threadIdentifier: UInt64 = 0,
        message: String,
        composedMessage: String = "",
        activityIdentifier: UInt64 = 0,
        source: LogSourceType = .osLog
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.subsystem = subsystem
        self.category = category
        self.process = process
        self.processIdentifier = processIdentifier
        self.threadIdentifier = threadIdentifier
        self.message = message
        self.composedMessage = composedMessage.isEmpty ? message : composedMessage
        self.activityIdentifier = activityIdentifier
        self.source = source
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(timestamp)
        hasher.combine(processIdentifier)
        hasher.combine(threadIdentifier)
        hasher.combine(message)
    }

    static func == (lhs: LogEntry, rhs: LogEntry) -> Bool {
        lhs.id == rhs.id
    }
}

extension LogEntry {
    @available(macOS 12.0, *)
    init(from osLogEntry: OSLogEntryLog) {
        self.id = UUID()
        self.timestamp = osLogEntry.date
        self.level = LogLevel(from: osLogEntry.level)
        self.subsystem = osLogEntry.subsystem
        self.category = osLogEntry.category
        self.process = osLogEntry.process
        self.processIdentifier = osLogEntry.processIdentifier
        self.threadIdentifier = osLogEntry.threadIdentifier
        self.message = osLogEntry.composedMessage
        self.composedMessage = osLogEntry.composedMessage
        self.activityIdentifier = osLogEntry.activityIdentifier
        self.source = .osLog
    }
}

extension LogLevel {
    @available(macOS 12.0, *)
    init(from osLogLevel: OSLogEntryLog.Level) {
        switch osLogLevel {
        case .undefined:
            self = .debug
        case .debug:
            self = .debug
        case .info:
            self = .info
        case .notice:
            self = .notice
        case .error:
            self = .error
        case .fault:
            self = .fault
        @unknown default:
            self = .info
        }
    }
}

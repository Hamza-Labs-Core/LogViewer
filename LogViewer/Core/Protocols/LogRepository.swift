import Foundation

protocol LogRepository: Sendable {
    func fetchLogs(filter: LogFilter) async throws -> [LogEntry]
    func fetchLogs(since date: Date, filter: LogFilter) async throws -> [LogEntry]
}

extension LogRepository {
    func fetchLogs(since date: Date, filter: LogFilter) async throws -> [LogEntry] {
        var modifiedFilter = filter
        modifiedFilter.timeRange = TimeRange(startDate: date)
        return try await fetchLogs(filter: modifiedFilter)
    }
}

enum LogRepositoryError: Error, LocalizedError {
    case notAvailable
    case accessDenied
    case invalidLogStore
    case parsingFailed(String)
    case fileNotFound(URL)
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Log store is not available"
        case .accessDenied:
            return "Access to logs was denied. Check system permissions."
        case .invalidLogStore:
            return "Failed to initialize log store"
        case .parsingFailed(let message):
            return "Failed to parse log entry: \(message)"
        case .fileNotFound(let url):
            return "Log file not found: \(url.path)"
        case .unsupportedFormat:
            return "Unsupported log format"
        }
    }
}

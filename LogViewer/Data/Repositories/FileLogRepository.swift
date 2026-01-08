import Foundation

final class FileLogRepository: LogRepository, Sendable {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func fetchLogs(filter: LogFilter) async throws -> [LogEntry] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let entries = try self.parseLogFile()
                    let filtered = filter.isActive ? entries.filter { filter.matches($0) } : entries
                    continuation.resume(returning: filtered)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func parseLogFile() throws -> [LogEntry] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw LogRepositoryError.fileNotFound(fileURL)
        }

        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)

        var entries: [LogEntry] = []

        for line in lines where !line.isEmpty {
            if let entry = parseLogLine(line) {
                entries.append(entry)
            }
        }

        return entries
    }

    private func parseLogLine(_ line: String) -> LogEntry? {
        if let jsonEntry = parseJSONLine(line) {
            return jsonEntry
        }

        return parseTextLine(line)
    }

    private func parseJSONLine(_ line: String) -> LogEntry? {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let timestamp: Date
        if let timestampString = json["timestamp"] as? String {
            timestamp = ISO8601DateFormatter().date(from: timestampString) ?? Date()
        } else if let timestampDouble = json["timestamp"] as? Double {
            timestamp = Date(timeIntervalSince1970: timestampDouble)
        } else {
            timestamp = Date()
        }

        let level = parseLevel(from: json["level"] as? String ?? json["severity"] as? String)
        let message = json["message"] as? String ?? json["msg"] as? String ?? ""
        let process = json["process"] as? String ?? json["logger"] as? String ?? ""
        let subsystem = json["subsystem"] as? String ?? ""
        let category = json["category"] as? String ?? ""

        return LogEntry(
            timestamp: timestamp,
            level: level,
            subsystem: subsystem,
            category: category,
            process: process,
            message: message,
            source: .file
        )
    }

    private func parseTextLine(_ line: String) -> LogEntry? {
        let patterns: [NSRegularExpression] = [
            try! NSRegularExpression(pattern: #"^(\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?)\s*\[?(\w+)\]?\s*(?:\[([^\]]+)\])?\s*(.*)$"#),
            try! NSRegularExpression(pattern: #"^(\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+(\S+)\s+(\S+?)(?:\[\d+\])?:\s*(.*)$"#),
            try! NSRegularExpression(pattern: #"^(\d{2}:\d{2}:\d{2}(?:\.\d+)?)\s+(\w+)\s+(.*)$"#)
        ]

        for pattern in patterns {
            let range = NSRange(line.startIndex..., in: line)
            if let match = pattern.firstMatch(in: line, range: range) {
                return extractEntry(from: match, in: line)
            }
        }

        return LogEntry(
            timestamp: Date(),
            level: .info,
            message: line,
            source: .file
        )
    }

    private func extractEntry(from match: NSTextCheckingResult, in line: String) -> LogEntry {
        func group(_ index: Int) -> String? {
            guard index < match.numberOfRanges else { return nil }
            let range = match.range(at: index)
            guard range.location != NSNotFound else { return nil }
            return String(line[Range(range, in: line)!])
        }

        let timestampStr = group(1) ?? ""
        let timestamp = parseDate(timestampStr) ?? Date()

        var level: LogLevel = .info
        var process = ""
        var message = ""

        if match.numberOfRanges >= 5 {
            level = parseLevel(from: group(2))
            process = group(3) ?? ""
            message = group(4) ?? ""
        } else if match.numberOfRanges >= 4 {
            let secondGroup = group(2) ?? ""
            if isLevel(secondGroup) {
                level = parseLevel(from: secondGroup)
                message = group(3) ?? ""
            } else {
                process = secondGroup
                message = group(3) ?? ""
            }
        } else {
            message = group(2) ?? line
        }

        return LogEntry(
            timestamp: timestamp,
            level: level,
            process: process,
            message: message,
            source: .file
        )
    }

    private func parseDate(_ string: String) -> Date? {
        let formatters: [DateFormatter] = [
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "MMM dd HH:mm:ss"
                f.defaultDate = Date()
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "HH:mm:ss.SSS"
                f.defaultDate = Date()
                return f
            }()
        ]

        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.date(from: string)
    }

    private func isLevel(_ string: String) -> Bool {
        let levels = ["debug", "info", "notice", "warning", "warn", "error", "err", "fault", "critical", "fatal"]
        return levels.contains(string.lowercased())
    }

    private func parseLevel(from string: String?) -> LogLevel {
        guard let string = string?.lowercased() else { return .info }

        switch string {
        case "debug", "trace", "verbose":
            return .debug
        case "info":
            return .info
        case "notice", "default":
            return .notice
        case "warning", "warn":
            return .warning
        case "error", "err":
            return .error
        case "fault", "critical", "fatal":
            return .fault
        default:
            return .info
        }
    }
}

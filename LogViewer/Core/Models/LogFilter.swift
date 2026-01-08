import Foundation

struct LogFilter: Equatable, Sendable {
    var levels: Set<LogLevel>
    var minimumLevel: LogLevel?
    var subsystem: String?
    var category: String?
    var process: String?
    var searchText: String?
    var timeRange: TimeRange?

    init(
        levels: Set<LogLevel> = Set(LogLevel.allCases),
        minimumLevel: LogLevel? = nil,
        subsystem: String? = nil,
        category: String? = nil,
        process: String? = nil,
        searchText: String? = nil,
        timeRange: TimeRange? = nil
    ) {
        self.levels = levels
        self.minimumLevel = minimumLevel
        self.subsystem = subsystem
        self.category = category
        self.process = process
        self.searchText = searchText
        self.timeRange = timeRange
    }

    static let `default` = LogFilter()

    var isActive: Bool {
        levels.count < LogLevel.allCases.count ||
        minimumLevel != nil ||
        subsystem != nil ||
        category != nil ||
        process != nil ||
        (searchText != nil && !searchText!.isEmpty) ||
        timeRange != nil
    }

    func matches(_ entry: LogEntry) -> Bool {
        if let minimumLevel = minimumLevel, entry.level < minimumLevel {
            return false
        }

        if !levels.contains(entry.level) {
            return false
        }

        if let subsystem = subsystem, !subsystem.isEmpty,
           !entry.subsystem.localizedCaseInsensitiveContains(subsystem) {
            return false
        }

        if let category = category, !category.isEmpty,
           !entry.category.localizedCaseInsensitiveContains(category) {
            return false
        }

        if let process = process, !process.isEmpty,
           !entry.process.localizedCaseInsensitiveContains(process) {
            return false
        }

        if let searchText = searchText, !searchText.isEmpty {
            let lowercased = searchText.lowercased()
            let found = entry.message.lowercased().contains(lowercased) ||
                       entry.process.lowercased().contains(lowercased) ||
                       entry.subsystem.lowercased().contains(lowercased) ||
                       entry.category.lowercased().contains(lowercased)
            if !found {
                return false
            }
        }

        if let range = timeRange {
            if !range.contains(entry.timestamp) {
                return false
            }
        }

        return true
    }
}

struct TimeRange: Equatable, Sendable {
    let startDate: Date
    let endDate: Date

    init(startDate: Date, endDate: Date = Date()) {
        self.startDate = startDate
        self.endDate = endDate
    }

    func contains(_ date: Date) -> Bool {
        date >= startDate && date <= endDate
    }

    static var lastHour: TimeRange {
        TimeRange(startDate: Date().addingTimeInterval(-3600))
    }

    static var last24Hours: TimeRange {
        TimeRange(startDate: Date().addingTimeInterval(-86400))
    }

    static var last7Days: TimeRange {
        TimeRange(startDate: Date().addingTimeInterval(-604800))
    }

    static var today: TimeRange {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        return TimeRange(startDate: startOfDay)
    }
}

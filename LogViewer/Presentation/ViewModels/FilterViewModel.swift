import Foundation
import Combine

@MainActor
final class FilterViewModel: ObservableObject {
    @Published var levels: Set<LogLevel> = Set(LogLevel.allCases)
    @Published var minimumLevel: LogLevel?
    @Published var processFilter: String = ""
    @Published var subsystemFilter: String = ""
    @Published var timeRangeOption: TimeRangeOption = .all

    enum TimeRangeOption: String, CaseIterable, Identifiable {
        case all = "All Time"
        case lastHour = "Last Hour"
        case last24Hours = "Last 24 Hours"
        case last7Days = "Last 7 Days"
        case today = "Today"

        var id: String { rawValue }

        var timeRange: TimeRange? {
            switch self {
            case .all: return nil
            case .lastHour: return .lastHour
            case .last24Hours: return .last24Hours
            case .last7Days: return .last7Days
            case .today: return .today
            }
        }
    }

    var filter: LogFilter {
        LogFilter(
            levels: levels,
            minimumLevel: minimumLevel,
            subsystem: subsystemFilter.isEmpty ? nil : subsystemFilter,
            process: processFilter.isEmpty ? nil : processFilter,
            timeRange: timeRangeOption.timeRange
        )
    }

    func isLevelEnabled(_ level: LogLevel) -> Bool {
        levels.contains(level)
    }

    func setLevelEnabled(_ level: LogLevel, _ enabled: Bool) {
        if enabled {
            levels.insert(level)
        } else {
            levels.remove(level)
        }
    }

    func toggleLevel(_ level: LogLevel) {
        if levels.contains(level) {
            levels.remove(level)
        } else {
            levels.insert(level)
        }
    }

    func showAllLevels() {
        levels = Set(LogLevel.allCases)
        minimumLevel = nil
    }

    func setMinimumLevel(_ level: LogLevel) {
        minimumLevel = level
        levels = Set(LogLevel.allCases.filter { $0 >= level })
    }

    func reset() {
        levels = Set(LogLevel.allCases)
        minimumLevel = nil
        processFilter = ""
        subsystemFilter = ""
        timeRangeOption = .all
    }
}

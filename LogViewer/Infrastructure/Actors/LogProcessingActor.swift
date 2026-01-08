import Foundation

actor LogProcessingActor {
    private var cache: [String: [LogEntry]] = [:]
    private let maxCacheSize = 3  // Reduced to save memory

    func fetchAndFilter(
        from repository: any LogRepository,
        filter: LogFilter
    ) async throws -> [LogEntry] {
        let cacheKey = makeCacheKey(for: filter)

        if let cached = cache[cacheKey] {
            return cached
        }

        let entries = try await repository.fetchLogs(filter: filter)

        updateCache(key: cacheKey, entries: entries)

        return entries
    }

    func filter(_ entries: [LogEntry], with filter: LogFilter) -> [LogEntry] {
        guard filter.isActive else { return entries }
        return entries.filter { filter.matches($0) }
    }

    func sort(_ entries: [LogEntry], by keyPath: KeyPath<LogEntry, Date>, ascending: Bool = false) -> [LogEntry] {
        entries.sorted { lhs, rhs in
            ascending ? lhs[keyPath: keyPath] < rhs[keyPath: keyPath]
                      : lhs[keyPath: keyPath] > rhs[keyPath: keyPath]
        }
    }

    func group(_ entries: [LogEntry], by keyPath: KeyPath<LogEntry, String>) -> [String: [LogEntry]] {
        Dictionary(grouping: entries) { $0[keyPath: keyPath] }
    }

    func deduplicate(_ entries: [LogEntry]) -> [LogEntry] {
        var seen = Set<Int>()
        return entries.filter { entry in
            var hasher = Hasher()
            entry.hash(into: &hasher)
            let hash = hasher.finalize()
            if seen.contains(hash) {
                return false
            }
            seen.insert(hash)
            return true
        }
    }

    func statistics(for entries: [LogEntry]) -> LogStatistics {
        var levelCounts: [LogLevel: Int] = [:]
        var processCounts: [String: Int] = [:]
        var subsystemCounts: [String: Int] = [:]

        for entry in entries {
            levelCounts[entry.level, default: 0] += 1
            if !entry.process.isEmpty {
                processCounts[entry.process, default: 0] += 1
            }
            if !entry.subsystem.isEmpty {
                subsystemCounts[entry.subsystem, default: 0] += 1
            }
        }

        return LogStatistics(
            totalCount: entries.count,
            levelCounts: levelCounts,
            processCounts: processCounts,
            subsystemCounts: subsystemCounts
        )
    }

    func clearCache() {
        cache.removeAll()
    }

    private func makeCacheKey(for filter: LogFilter) -> String {
        var components: [String] = []

        if let subsystem = filter.subsystem {
            components.append("sub:\(subsystem)")
        }
        if let category = filter.category {
            components.append("cat:\(category)")
        }
        if let process = filter.process {
            components.append("proc:\(process)")
        }
        if let timeRange = filter.timeRange {
            components.append("time:\(timeRange.startDate.timeIntervalSince1970)")
        }

        return components.joined(separator: "|")
    }

    private func updateCache(key: String, entries: [LogEntry]) {
        if cache.count >= maxCacheSize {
            cache.removeValue(forKey: cache.keys.first!)
        }
        cache[key] = entries
    }
}

struct LogStatistics: Sendable {
    let totalCount: Int
    let levelCounts: [LogLevel: Int]
    let processCounts: [String: Int]
    let subsystemCounts: [String: Int]

    var errorCount: Int {
        (levelCounts[.error] ?? 0) + (levelCounts[.fault] ?? 0)
    }

    var warningCount: Int {
        levelCounts[.warning] ?? 0
    }

    var topProcesses: [(String, Int)] {
        processCounts.sorted { $0.value > $1.value }.prefix(10).map { ($0.key, $0.value) }
    }

    var topSubsystems: [(String, Int)] {
        subsystemCounts.sorted { $0.value > $1.value }.prefix(10).map { ($0.key, $0.value) }
    }
}

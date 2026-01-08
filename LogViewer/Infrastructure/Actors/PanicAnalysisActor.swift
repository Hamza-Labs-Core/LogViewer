import Foundation

actor PanicAnalysisActor {
    private var cachedRestarts: [SystemRestart]?
    private var cachedAnalyses: [UUID: RestartAnalysis] = [:]
    private let repository: PanicRepository
    private let useCase: AnalyzeRestartUseCase

    init(repository: PanicRepository = PanicLogRepository()) {
        self.repository = repository
        self.useCase = AnalyzeRestartUseCase(repository: repository)
    }

    func fetchRestarts(forceRefresh: Bool = false) async throws -> [SystemRestart] {
        if !forceRefresh, let cached = cachedRestarts {
            return cached
        }

        let restarts = try await useCase.analyzeRestarts()
        cachedRestarts = restarts
        return restarts
    }

    func analyze(_ restart: SystemRestart) -> RestartAnalysis {
        if let cached = cachedAnalyses[restart.id] {
            return cached
        }

        let analysis = useCase.analyzeCause(for: restart)
        cachedAnalyses[restart.id] = analysis
        return analysis
    }

    func statistics(for restarts: [SystemRestart]) -> RestartStatistics {
        var typeCounts: [RestartType: Int] = [:]
        var totalCrashes = 0
        var panicCount = 0

        for restart in restarts {
            typeCounts[restart.type, default: 0] += 1
            totalCrashes += restart.relatedCrashes.count
            if restart.panic != nil {
                panicCount += 1
            }
        }

        let recentRestarts = restarts.filter {
            $0.timestamp > Date().addingTimeInterval(-7 * 24 * 60 * 60)
        }

        return RestartStatistics(
            totalCount: restarts.count,
            panicCount: panicCount,
            typeCounts: typeCounts,
            relatedCrashCount: totalCrashes,
            recentCount: recentRestarts.count
        )
    }

    func findPattern(in restarts: [SystemRestart]) -> [String] {
        var patterns: [String] = []

        let byType = Dictionary(grouping: restarts) { $0.type }
        for (type, typeRestarts) in byType where typeRestarts.count > 1 {
            patterns.append("Multiple \(type.displayName) restarts detected (\(typeRestarts.count) occurrences)")
        }

        let allCrashes = restarts.flatMap { $0.relatedCrashes }
        let crashesByProcess = Dictionary(grouping: allCrashes) { $0.processName }
        for (process, processCrashes) in crashesByProcess where processCrashes.count > 2 {
            patterns.append("\(process) crashed \(processCrashes.count) times across restarts - possible recurring issue")
        }

        let recentRestarts = restarts.filter {
            $0.timestamp > Date().addingTimeInterval(-24 * 60 * 60)
        }
        if recentRestarts.count > 2 {
            patterns.append("Warning: \(recentRestarts.count) restarts in the last 24 hours")
        }

        return patterns
    }

    func clearCache() {
        cachedRestarts = nil
        cachedAnalyses.removeAll()
    }
}

struct RestartStatistics: Sendable {
    let totalCount: Int
    let panicCount: Int
    let typeCounts: [RestartType: Int]
    let relatedCrashCount: Int
    let recentCount: Int

    var watchdogCount: Int {
        typeCounts[.watchdog] ?? 0
    }

    var kernelPanicCount: Int {
        typeCounts[.kernelPanic] ?? 0
    }

    var unexpectedCount: Int {
        typeCounts[.unexpected] ?? 0
    }
}

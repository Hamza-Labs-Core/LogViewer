import Foundation

final class AnalyzeRestartUseCase: Sendable {
    private let repository: PanicRepository

    init(repository: PanicRepository = PanicLogRepository()) {
        self.repository = repository
    }

    func analyzeRestarts() async throws -> [SystemRestart] {
        try await repository.fetchSystemRestarts()
    }

    func analyzeCause(for restart: SystemRestart) -> RestartAnalysis {
        var analysis = RestartAnalysis(restart: restart)

        if let panic = restart.panic {
            analysis.primaryCause = determinePrimaryCause(panic)
            analysis.severity = determineSeverity(panic)
            analysis.explanation = generateExplanation(panic)
            analysis.recommendations = generateRecommendations(panic, crashes: restart.relatedCrashes)
        } else {
            analysis.primaryCause = "Unknown cause - no panic log recorded"
            analysis.severity = .medium
            analysis.explanation = "The system restarted without a recorded kernel panic. This may indicate a power loss or forced shutdown."
            analysis.recommendations = ["Check power connections", "Review system logs for anomalies"]
        }

        if !restart.relatedCrashes.isEmpty {
            analysis.relatedCauseAnalysis = analyzeRelatedCrashes(restart.relatedCrashes)
        }

        return analysis
    }

    private func determinePrimaryCause(_ panic: KernelPanic) -> String {
        let panicString = panic.panicString.lowercased()

        if panicString.contains("watchdog") && panicString.contains("reset") {
            return "SoC Watchdog Reset"
        }
        if panicString.contains("kernel panic") {
            return "Kernel Panic"
        }
        if panicString.contains("memory") || panicString.contains("zone") {
            return "Memory Subsystem Failure"
        }
        if panicString.contains("gpu") || panicString.contains("graphics") {
            return "Graphics Subsystem Failure"
        }
        if panicString.contains("io") || panicString.contains("disk") {
            return "I/O Subsystem Failure"
        }

        return "System Failure"
    }

    private func determineSeverity(_ panic: KernelPanic) -> RestartAnalysis.Severity {
        let notes = panic.notes.joined(separator: " ").lowercased()
        let panicString = panic.panicString.lowercased()

        if notes.contains("missing stackshot") {
            return .critical
        }
        if panicString.contains("watchdog") {
            return .high
        }
        if panic.bootFailureCount ?? 0 > 1 {
            return .critical
        }

        return .medium
    }

    private func generateExplanation(_ panic: KernelPanic) -> String {
        let panicString = panic.panicString.lowercased()
        var explanation = ""

        if panicString.contains("watchdog") {
            explanation = "The system became unresponsive and the hardware watchdog timer triggered a forced reset. "
            if panicString.contains("panic save chip reset") {
                explanation += "A kernel panic occurred but the system was too frozen to capture full diagnostics before the watchdog reset."
            }
        } else if panicString.contains("kernel panic") {
            explanation = "The kernel encountered a fatal error and could not continue operation safely. "
        }

        if panic.notes.contains("missing stackshot buffer or size") {
            explanation += " Note: The system was too unresponsive to capture a full diagnostic stack trace."
        }

        if let bootFaults = panic.bootFaults, !bootFaults.isEmpty {
            explanation += " Boot fault indicators: \(bootFaults)"
        }

        return explanation.isEmpty ? panic.panicString : explanation
    }

    private func generateRecommendations(_ panic: KernelPanic, crashes: [CrashReport]) -> [String] {
        var recommendations: [String] = []

        let panicString = panic.panicString.lowercased()

        if panicString.contains("watchdog") {
            recommendations.append("Check for resource-intensive processes that may have caused a system hang")
            recommendations.append("Verify hardware peripherals are functioning correctly")
        }

        if !crashes.isEmpty {
            let processNames = Set(crashes.map { $0.processName })
            for name in processNames {
                recommendations.append("Investigate \(name) crashes that occurred before the restart")
            }
        }

        let dyldCrashes = crashes.filter { $0.crashType == .dyldError }
        if !dyldCrashes.isEmpty {
            recommendations.append("Check for missing or corrupted library files")
        }

        if panic.bootFailureCount ?? 0 > 0 {
            recommendations.append("Multiple boot failures detected - consider hardware diagnostics")
        }

        if recommendations.isEmpty {
            recommendations.append("Monitor system stability for recurring issues")
            recommendations.append("Keep macOS and applications updated")
        }

        return recommendations
    }

    private func analyzeRelatedCrashes(_ crashes: [CrashReport]) -> String {
        guard !crashes.isEmpty else { return "" }

        let crashesByType = Dictionary(grouping: crashes) { $0.crashType }
        var analysis = "Related crashes before restart:\n"

        for (type, typeCrashes) in crashesByType.sorted(by: { $0.value.count > $1.value.count }) {
            let processNames = Set(typeCrashes.map { $0.processName })
            analysis += "- \(type.displayName): \(processNames.joined(separator: ", "))\n"
        }

        if let mostRecent = crashes.sorted(by: { $0.timestamp > $1.timestamp }).first {
            analysis += "\nMost recent crash: \(mostRecent.processName) (\(mostRecent.terminationReason))"
            if !mostRecent.terminationDetails.isEmpty {
                analysis += "\n  Details: \(mostRecent.terminationDetails.first ?? "")"
            }
        }

        return analysis
    }
}

struct RestartAnalysis: Sendable {
    enum Severity: String, Sendable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case critical = "Critical"

        var color: String {
            switch self {
            case .low: return "green"
            case .medium: return "yellow"
            case .high: return "orange"
            case .critical: return "red"
            }
        }
    }

    let restart: SystemRestart
    var primaryCause: String = ""
    var severity: Severity = .medium
    var explanation: String = ""
    var recommendations: [String] = []
    var relatedCauseAnalysis: String = ""
}

import Foundation
import OSLog

final class OSLogRepository: LogRepository, Sendable {
    enum Scope: Sendable {
        case currentProcess
        case system
    }

    private let scope: Scope

    init(scope: Scope = .currentProcess) {
        self.scope = scope
    }

    func fetchLogs(filter: LogFilter) async throws -> [LogEntry] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let entries = try self.fetchLogsSync(filter: filter)
                    continuation.resume(returning: entries)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func fetchLogsSync(filter: LogFilter) throws -> [LogEntry] {
        let store: OSLogStore

        // Suppress stderr noise from OSLog framework
        let originalStderr = dup(STDERR_FILENO)
        let devNull = open("/dev/null", O_WRONLY)
        dup2(devNull, STDERR_FILENO)
        close(devNull)

        defer {
            // Restore stderr
            dup2(originalStderr, STDERR_FILENO)
            close(originalStderr)
        }

        switch scope {
        case .currentProcess:
            store = try OSLogStore(scope: .currentProcessIdentifier)
        case .system:
            #if APPSTORE
            throw LogRepositoryError.accessDenied
            #else
            store = try OSLogStore.local()
            #endif
        }

        let position: OSLogPosition
        if let startDate = filter.timeRange?.startDate {
            position = store.position(date: startDate)
        } else {
            position = store.position(timeIntervalSinceLatestBoot: 0)
        }

        let predicate = buildPredicate(from: filter)

        let maxEntries = 10_000
        var entries: [LogEntry] = []
        entries.reserveCapacity(maxEntries)

        let rawEntries: AnySequence<OSLogEntry>
        if let predicate = predicate {
            rawEntries = try store.getEntries(at: position, matching: predicate)
        } else {
            rawEntries = try store.getEntries(at: position)
        }

        for entry in rawEntries {
            guard entries.count < maxEntries else { break }

            if let logEntry = entry as? OSLogEntryLog {
                let converted = LogEntry(from: logEntry)
                if !filter.isActive || filter.matches(converted) {
                    entries.append(converted)
                }
            }
        }

        return entries
    }

    private func buildPredicate(from filter: LogFilter) -> NSPredicate? {
        var predicates: [NSPredicate] = []

        if let subsystem = filter.subsystem, !subsystem.isEmpty {
            predicates.append(NSPredicate(format: "subsystem CONTAINS[c] %@", subsystem))
        }

        if let category = filter.category, !category.isEmpty {
            predicates.append(NSPredicate(format: "category CONTAINS[c] %@", category))
        }

        guard !predicates.isEmpty else { return nil }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
}

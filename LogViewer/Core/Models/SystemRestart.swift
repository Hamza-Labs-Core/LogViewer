import Foundation

struct SystemRestart: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    let timestamp: Date
    let type: RestartType
    let panic: KernelPanic?
    let relatedCrashes: [CrashReport]
    let bootSessionUUID: String?

    init(
        id: UUID = UUID(),
        timestamp: Date,
        type: RestartType,
        panic: KernelPanic? = nil,
        relatedCrashes: [CrashReport] = [],
        bootSessionUUID: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.panic = panic
        self.relatedCrashes = relatedCrashes
        self.bootSessionUUID = bootSessionUUID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(timestamp)
        hasher.combine(type)
    }

    static func == (lhs: SystemRestart, rhs: SystemRestart) -> Bool {
        lhs.id == rhs.id
    }
}

extension SystemRestart {
    var displayTitle: String {
        type.displayName
    }

    var causeSummary: String {
        if let panic = panic {
            return panic.causeSummary
        }
        switch type {
        case .cleanShutdown:
            return "Normal system shutdown"
        case .unexpected:
            return "Unexpected restart without panic log"
        default:
            return type.displayName
        }
    }

    var hasRelatedCrashes: Bool {
        !relatedCrashes.isEmpty
    }

    var probableCause: String? {
        guard !relatedCrashes.isEmpty else { return nil }
        let sorted = relatedCrashes.sorted { $0.timestamp > $1.timestamp }
        if let mostRecent = sorted.first {
            return "Possibly caused by \(mostRecent.processName) crash"
        }
        return nil
    }
}

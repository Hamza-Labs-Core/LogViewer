import Foundation

struct KernelPanic: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    let timestamp: Date
    let incidentId: String
    let panicString: String
    let kernel: String
    let osVersion: String
    let buildVersion: String
    let product: String
    let socId: String?
    let socRevision: String?
    let bootFaults: String?
    let bootFailureCount: Int?
    let notes: [String]

    init(
        id: UUID = UUID(),
        timestamp: Date,
        incidentId: String,
        panicString: String,
        kernel: String = "",
        osVersion: String = "",
        buildVersion: String = "",
        product: String = "",
        socId: String? = nil,
        socRevision: String? = nil,
        bootFaults: String? = nil,
        bootFailureCount: Int? = nil,
        notes: [String] = []
    ) {
        self.id = id
        self.timestamp = timestamp
        self.incidentId = incidentId
        self.panicString = panicString
        self.kernel = kernel
        self.osVersion = osVersion
        self.buildVersion = buildVersion
        self.product = product
        self.socId = socId
        self.socRevision = socRevision
        self.bootFaults = bootFaults
        self.bootFailureCount = bootFailureCount
        self.notes = notes
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(timestamp)
        hasher.combine(incidentId)
    }

    static func == (lhs: KernelPanic, rhs: KernelPanic) -> Bool {
        lhs.id == rhs.id
    }
}

extension KernelPanic {
    var restartType: RestartType {
        if panicString.lowercased().contains("watchdog") {
            return .watchdog
        }
        if panicString.lowercased().contains("panic") {
            return .kernelPanic
        }
        return .unexpected
    }

    var causeSummary: String {
        if panicString.contains("watchdog reset") {
            return "System became unresponsive; hardware watchdog triggered reset"
        }
        if panicString.contains("panic save chip reset") {
            return "Kernel panic with SoC watchdog reset"
        }
        if panicString.contains("kernel panic") {
            return "Kernel software crash"
        }
        return panicString
    }

    var hasStackTrace: Bool {
        !notes.contains("missing stackshot buffer or size")
    }
}

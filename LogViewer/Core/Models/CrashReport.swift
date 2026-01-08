import Foundation

struct CrashReport: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    let timestamp: Date
    let processName: String
    let processPath: String
    let terminationReason: String
    let terminationDetails: [String]
    let parentProcess: String?
    let crashType: CrashType
    let exceptionType: String?
    let signal: String?
    let osVersion: String
    let incidentId: String

    init(
        id: UUID = UUID(),
        timestamp: Date,
        processName: String,
        processPath: String,
        terminationReason: String,
        terminationDetails: [String] = [],
        parentProcess: String? = nil,
        crashType: CrashType,
        exceptionType: String? = nil,
        signal: String? = nil,
        osVersion: String = "",
        incidentId: String = ""
    ) {
        self.id = id
        self.timestamp = timestamp
        self.processName = processName
        self.processPath = processPath
        self.terminationReason = terminationReason
        self.terminationDetails = terminationDetails
        self.parentProcess = parentProcess
        self.crashType = crashType
        self.exceptionType = exceptionType
        self.signal = signal
        self.osVersion = osVersion
        self.incidentId = incidentId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(timestamp)
        hasher.combine(processName)
        hasher.combine(incidentId)
    }

    static func == (lhs: CrashReport, rhs: CrashReport) -> Bool {
        lhs.id == rhs.id
    }
}

extension CrashReport {
    var summaryDescription: String {
        if !terminationDetails.isEmpty {
            return terminationDetails.first ?? terminationReason
        }
        return terminationReason
    }
}

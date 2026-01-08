import Foundation

final class PanicLogRepository: PanicRepository, Sendable {
    private let systemDiagnosticsURL: URL
    private let userDiagnosticsURL: URL

    init(
        systemDiagnosticsURL: URL = URL(fileURLWithPath: "/Library/Logs/DiagnosticReports"),
        userDiagnosticsURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/DiagnosticReports")
    ) {
        self.systemDiagnosticsURL = systemDiagnosticsURL
        self.userDiagnosticsURL = userDiagnosticsURL
    }

    func fetchPanics() async throws -> [KernelPanic] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let panics = try self.parsePanicFiles()
                    continuation.resume(returning: panics)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchCrashReports(around date: Date, windowMinutes: Int = 30) async throws -> [CrashReport] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let crashes = try self.parseCrashReports(around: date, windowMinutes: windowMinutes)
                    continuation.resume(returning: crashes)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchSystemRestarts() async throws -> [SystemRestart] {
        let panics = try await fetchPanics()
        var restarts: [SystemRestart] = []

        for panic in panics {
            let relatedCrashes = try await fetchCrashReports(around: panic.timestamp, windowMinutes: 30)
            let restart = SystemRestart(
                timestamp: panic.timestamp,
                type: panic.restartType,
                panic: panic,
                relatedCrashes: relatedCrashes
            )
            restarts.append(restart)
        }

        return restarts.sorted { $0.timestamp > $1.timestamp }
    }

    private func parsePanicFiles() throws -> [KernelPanic] {
        var panics: [KernelPanic] = []
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: systemDiagnosticsURL.path) else {
            throw PanicRepositoryError.directoryNotFound(systemDiagnosticsURL)
        }

        let panicFiles = try fileManager.contentsOfDirectory(at: systemDiagnosticsURL, includingPropertiesForKeys: [.contentModificationDateKey])
            .filter { $0.pathExtension == "panic" }

        for fileURL in panicFiles {
            if let panic = try? parsePanicFile(fileURL) {
                var updatedPanic = panic
                if let resetInfo = findMatchingResetCounter(for: panic.timestamp) {
                    updatedPanic = KernelPanic(
                        id: panic.id,
                        timestamp: panic.timestamp,
                        incidentId: panic.incidentId,
                        panicString: panic.panicString,
                        kernel: panic.kernel,
                        osVersion: panic.osVersion,
                        buildVersion: panic.buildVersion,
                        product: panic.product,
                        socId: panic.socId,
                        socRevision: panic.socRevision,
                        bootFaults: resetInfo.bootFaults,
                        bootFailureCount: resetInfo.bootFailureCount,
                        notes: panic.notes
                    )
                }
                panics.append(updatedPanic)
            }
        }

        return panics.sorted { $0.timestamp > $1.timestamp }
    }

    private func parsePanicFile(_ url: URL) throws -> KernelPanic {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)

        guard lines.count >= 2 else {
            throw PanicRepositoryError.parsingFailed("Invalid panic file format")
        }

        guard let jsonData = lines.dropFirst().joined(separator: "\n").data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw PanicRepositoryError.parsingFailed("Failed to parse panic JSON")
        }

        let dateString = json["date"] as? String ?? ""
        let timestamp = parsePanicDate(dateString) ?? Date()

        let notes: [String]
        if let notesArray = json["notes"] as? [String] {
            notes = notesArray
        } else {
            notes = []
        }

        return KernelPanic(
            timestamp: timestamp,
            incidentId: json["incident"] as? String ?? "",
            panicString: json["panicString"] as? String ?? "Unknown panic",
            kernel: json["kernel"] as? String ?? "",
            osVersion: json["build"] as? String ?? "",
            buildVersion: json["build"] as? String ?? "",
            product: json["product"] as? String ?? "",
            socId: json["socId"] as? String,
            socRevision: json["socRevision"] as? String,
            notes: notes
        )
    }

    private func findMatchingResetCounter(for panicDate: Date) -> (bootFaults: String, bootFailureCount: Int)? {
        let fileManager = FileManager.default

        guard let files = try? fileManager.contentsOfDirectory(at: systemDiagnosticsURL, includingPropertiesForKeys: nil) else {
            return nil
        }

        let resetFiles = files.filter { $0.lastPathComponent.hasPrefix("ResetCounter-") && $0.pathExtension == "diag" }

        for fileURL in resetFiles {
            if let info = try? parseResetCounter(fileURL) {
                let timeDiff = abs(info.timestamp.timeIntervalSince(panicDate))
                if timeDiff < 60 {
                    return (info.bootFaults, info.bootFailureCount)
                }
            }
        }

        return nil
    }

    private func parseResetCounter(_ url: URL) throws -> (timestamp: Date, bootFaults: String, bootFailureCount: Int) {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)

        var timestamp = Date()
        var bootFaults = ""
        var bootFailureCount = 0

        for line in lines {
            if line.hasPrefix("Date:") {
                let dateStr = line.replacingOccurrences(of: "Date: ", with: "").trimmingCharacters(in: .whitespaces)
                timestamp = parsePanicDate(dateStr) ?? Date()
            } else if line.hasPrefix("Boot faults:") {
                bootFaults = line.replacingOccurrences(of: "Boot faults: ", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("Boot failure count:") {
                let countStr = line.replacingOccurrences(of: "Boot failure count: ", with: "").trimmingCharacters(in: .whitespaces)
                bootFailureCount = Int(countStr) ?? 0
            }
        }

        return (timestamp, bootFaults, bootFailureCount)
    }

    private func parseCrashReports(around date: Date, windowMinutes: Int) throws -> [CrashReport] {
        var crashes: [CrashReport] = []
        let fileManager = FileManager.default
        let windowStart = date.addingTimeInterval(-Double(windowMinutes) * 60)

        for diagnosticsURL in [systemDiagnosticsURL, userDiagnosticsURL] {
            guard fileManager.fileExists(atPath: diagnosticsURL.path) else { continue }

            let files = try fileManager.contentsOfDirectory(at: diagnosticsURL, includingPropertiesForKeys: [.contentModificationDateKey])
                .filter { $0.pathExtension == "ips" }

            for fileURL in files {
                if let crash = try? parseCrashReport(fileURL) {
                    if crash.timestamp >= windowStart && crash.timestamp <= date {
                        crashes.append(crash)
                    }
                }
            }
        }

        return crashes.sorted { $0.timestamp > $1.timestamp }
    }

    private func parseCrashReport(_ url: URL) throws -> CrashReport {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)

        guard !lines.isEmpty,
              let headerData = lines[0].data(using: .utf8),
              let header = try? JSONSerialization.jsonObject(with: headerData) as? [String: Any] else {
            throw PanicRepositoryError.parsingFailed("Invalid crash report format")
        }

        let timestampStr = header["timestamp"] as? String ?? ""
        let timestamp = parsePanicDate(timestampStr) ?? Date()

        var json: [String: Any] = [:]
        if lines.count > 1 {
            let bodyContent = lines.dropFirst().joined(separator: "\n")
            if let bodyData = bodyContent.data(using: .utf8),
               let bodyJson = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] {
                json = bodyJson
            }
        }

        let termination = json["termination"] as? [String: Any] ?? [:]
        let terminationReasons = termination["reasons"] as? [String] ?? []
        let terminationIndicator = termination["indicator"] as? String ?? ""

        let exception = json["exception"] as? [String: Any] ?? [:]
        let exceptionType = exception["type"] as? String
        let signal = exception["signal"] as? String

        let crashType = determineCrashType(
            fatalDyldError: json["fatalDyldError"] as? Int == 1,
            exceptionType: exceptionType,
            signal: signal
        )

        return CrashReport(
            timestamp: timestamp,
            processName: header["app_name"] as? String ?? json["procName"] as? String ?? "Unknown",
            processPath: json["procPath"] as? String ?? "",
            terminationReason: terminationIndicator,
            terminationDetails: terminationReasons,
            parentProcess: json["parentProc"] as? String,
            crashType: crashType,
            exceptionType: exceptionType,
            signal: signal,
            osVersion: header["os_version"] as? String ?? "",
            incidentId: header["incident_id"] as? String ?? json["incident"] as? String ?? ""
        )
    }

    private func determineCrashType(fatalDyldError: Bool, exceptionType: String?, signal: String?) -> CrashType {
        if fatalDyldError {
            return .dyldError
        }
        if let signal = signal, !signal.isEmpty {
            return .signal
        }
        if let exceptionType = exceptionType, !exceptionType.isEmpty {
            if exceptionType.contains("RESOURCE") {
                return .resourceLimit
            }
            return .exception
        }
        return .unknown
    }

    private func parsePanicDate(_ dateString: String) -> Date? {
        let formatters: [DateFormatter] = [
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd HH:mm:ss.SS Z"
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSS Z"
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd HH:mm:ss.SS"
                return f
            }()
        ]

        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        return nil
    }
}

import Foundation
import UniformTypeIdentifiers

final class ExportLogsUseCase: Sendable {
    enum ExportFormat: String, CaseIterable, Identifiable {
        case plainText = "Plain Text"
        case json = "JSON"
        case csv = "CSV"

        var id: String { rawValue }

        var fileExtension: String {
            switch self {
            case .plainText: return "log"
            case .json: return "json"
            case .csv: return "csv"
            }
        }

        var contentType: UTType {
            switch self {
            case .plainText: return .plainText
            case .json: return .json
            case .csv: return .commaSeparatedText
            }
        }
    }

    func export(_ entries: [LogEntry], format: ExportFormat) throws -> Data {
        switch format {
        case .plainText:
            return exportAsText(entries)
        case .json:
            return try exportAsJSON(entries)
        case .csv:
            return exportAsCSV(entries)
        }
    }

    private func exportAsText(_ entries: [LogEntry]) -> Data {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        let lines = entries.map { entry in
            "\(formatter.string(from: entry.timestamp)) [\(entry.level.shortName)] \(entry.process): \(entry.message)"
        }

        return lines.joined(separator: "\n").data(using: .utf8) ?? Data()
    }

    private func exportAsJSON(_ entries: [LogEntry]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(entries)
    }

    private func exportAsCSV(_ entries: [LogEntry]) -> Data {
        var csv = "Timestamp,Level,Process,PID,Subsystem,Category,Message\n"

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for entry in entries {
            let escapedMessage = entry.message
                .replacingOccurrences(of: "\"", with: "\"\"")
                .replacingOccurrences(of: "\n", with: "\\n")

            csv += "\"\(formatter.string(from: entry.timestamp))\","
            csv += "\"\(entry.level.displayName)\","
            csv += "\"\(entry.process)\","
            csv += "\(entry.processIdentifier),"
            csv += "\"\(entry.subsystem)\","
            csv += "\"\(entry.category)\","
            csv += "\"\(escapedMessage)\"\n"
        }

        return csv.data(using: .utf8) ?? Data()
    }

    func suggestedFileName(format: ExportFormat) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        return "logs_\(timestamp).\(format.fileExtension)"
    }
}

import SwiftUI
import UniformTypeIdentifiers

struct ExportView: View {
    let entries: [LogEntry]
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFormat: ExportLogsUseCase.ExportFormat = .plainText
    @State private var isExporting = false
    @State private var exportError: String?

    private let exportUseCase = ExportLogsUseCase()

    var body: some View {
        VStack(spacing: 20) {
            Text("Export Logs")
                .font(.headline)

            Text("\(entries.count) log entries will be exported")
                .foregroundStyle(.secondary)

            Picker("Format", selection: $selectedFormat) {
                ForEach(ExportLogsUseCase.ExportFormat.allCases) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .pickerStyle(.segmented)

            if let error = exportError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .help("Cancel export")

                Button("Export...") {
                    exportLogs()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(entries.isEmpty)
                .help("Choose location and export logs")
            }
        }
        .padding()
        .frame(width: 300)
        .fileExporter(
            isPresented: $isExporting,
            document: LogDocument(entries: entries, format: selectedFormat),
            contentType: selectedFormat.contentType,
            defaultFilename: exportUseCase.suggestedFileName(format: selectedFormat)
        ) { result in
            switch result {
            case .success:
                dismiss()
            case .failure(let error):
                exportError = error.localizedDescription
            }
        }
    }

    private func exportLogs() {
        isExporting = true
    }
}

struct LogDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText, .json, .commaSeparatedText] }

    let entries: [LogEntry]
    let format: ExportLogsUseCase.ExportFormat

    init(entries: [LogEntry], format: ExportLogsUseCase.ExportFormat) {
        self.entries = entries
        self.format = format
    }

    init(configuration: ReadConfiguration) throws {
        entries = []
        format = .plainText
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let exportUseCase = ExportLogsUseCase()
        let data = try exportUseCase.export(entries, format: format)
        return FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    ExportView(entries: [
        LogEntry(timestamp: Date(), level: .info, message: "Test message 1"),
        LogEntry(timestamp: Date(), level: .error, message: "Test message 2")
    ])
}

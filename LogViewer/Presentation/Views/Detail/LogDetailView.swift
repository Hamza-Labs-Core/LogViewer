import SwiftUI

struct LogDetailView: View {
    let entry: LogEntry

    @State private var isCopied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Spacer()
                    Button {
                        copyToClipboard()
                    } label: {
                        Label(isCopied ? "Copied!" : "Copy", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Copy log entry to clipboard")
                }

                headerSection

                Divider()

                messageSection

                Divider()

                metadataSection
            }
            .padding()
        }
        .frame(minWidth: 250)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                LevelBadge(level: entry.level)
                Spacer()
                Text(entry.timestamp, style: .date)
                Text(entry.timestamp, style: .time)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !entry.process.isEmpty {
                Label(entry.process, systemImage: "app")
                    .font(.headline)
            }

            if !entry.subsystem.isEmpty {
                HStack {
                    Text(entry.subsystem)
                        .font(.subheadline)
                    if !entry.category.isEmpty {
                        Text("/")
                            .foregroundStyle(.tertiary)
                        Text(entry.category)
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Message")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text(entry.message)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Metadata")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    Text("Process ID")
                        .foregroundStyle(.secondary)
                    Text("\(entry.processIdentifier)")
                        .font(.system(.body, design: .monospaced))
                }

                GridRow {
                    Text("Thread ID")
                        .foregroundStyle(.secondary)
                    Text("\(entry.threadIdentifier)")
                        .font(.system(.body, design: .monospaced))
                }

                if entry.activityIdentifier != 0 {
                    GridRow {
                        Text("Activity ID")
                            .foregroundStyle(.secondary)
                        Text("\(entry.activityIdentifier)")
                            .font(.system(.body, design: .monospaced))
                    }
                }

                GridRow {
                    Text("Source")
                        .foregroundStyle(.secondary)
                    Text(entry.source.rawValue)
                        .font(.system(.body, design: .monospaced))
                }

                GridRow {
                    Text("Entry ID")
                        .foregroundStyle(.secondary)
                    Text(entry.id.uuidString)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func copyToClipboard() {
        let text = """
        [\(entry.level.displayName)] \(entry.timestamp)
        Process: \(entry.process) (\(entry.processIdentifier))
        Subsystem: \(entry.subsystem)/\(entry.category)

        \(entry.message)
        """

        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif

        withAnimation {
            isCopied = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                isCopied = false
            }
        }
    }
}

#Preview {
    LogDetailView(entry: LogEntry(
        timestamp: Date(),
        level: .error,
        subsystem: "com.example.app",
        category: "network",
        process: "Example",
        processIdentifier: 12345,
        threadIdentifier: 67890,
        message: "Failed to connect to server: Connection refused"
    ))
    .frame(width: 350)
}

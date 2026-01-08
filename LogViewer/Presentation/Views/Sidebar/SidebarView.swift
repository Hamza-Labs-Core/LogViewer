import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @Binding var selectedSource: LogSource
    var isStreaming: Bool
    var onStartStream: () -> Void
    var onStopStream: () -> Void
    var onQuickFilter: ((QuickFilter) -> Void)?
    var activeQuickFilter: QuickFilter?

    @State private var importedFiles: [URL] = []
    @State private var isImporting = false

    enum QuickFilter: Equatable {
        case errorsOnly
        case lastHour
    }

    var body: some View {
        List(selection: $selectedSource) {
            sourcesSection
            analysisSection
            filesSection
            quickFiltersSection
        }
        .listStyle(.sidebar)
        .frame(minWidth: 180)
        .toolbar {
            ToolbarItem {
                if selectedSource == .stream {
                    Button {
                        if isStreaming {
                            onStopStream()
                        } else {
                            onStartStream()
                        }
                    } label: {
                        Image(systemName: isStreaming ? "stop.fill" : "play.fill")
                    }
                    .help(isStreaming ? "Stop streaming" : "Start streaming")
                }
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.log, .plainText, .json],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                importedFiles.append(contentsOf: urls)
                if let firstURL = urls.first {
                    selectedSource = .file(firstURL)
                }
            case .failure:
                break
            }
        }
    }

    private var sourcesSection: some View {
        Section("Sources") {
            Label("App Logs", systemImage: "app.badge")
                .tag(LogSource.osLog)

            #if !APPSTORE
            Label("System Logs", systemImage: "gearshape.2")
                .tag(LogSource.systemLog)
            #endif

            HStack {
                Label("Live Stream", systemImage: "waveform")
                if isStreaming {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                }
            }
            .tag(LogSource.stream)
        }
    }

    private var analysisSection: some View {
        Section("Analysis") {
            Label("System Restarts", systemImage: "bolt.trianglebadge.exclamationmark")
                .tag(LogSource.systemRestarts)
        }
    }

    private var filesSection: some View {
        Section("Files") {
            ForEach(importedFiles, id: \.self) { url in
                Label(url.lastPathComponent, systemImage: "doc.text")
                    .tag(LogSource.file(url))
                    .contextMenu {
                        Button("Remove", role: .destructive) {
                            importedFiles.removeAll { $0 == url }
                        }
                    }
            }

            Button {
                isImporting = true
            } label: {
                Label("Import Log File...", systemImage: "plus")
            }
            .buttonStyle(.plain)
            .help("Import a log file from disk")
        }
    }

    private var quickFiltersSection: some View {
        Section("Quick Filters") {
            quickFilterButton(
                title: "Errors Only",
                icon: "xmark.circle",
                filter: .errorsOnly,
                help: "Show only error and fault level logs"
            )
            quickFilterButton(
                title: "Last Hour",
                icon: "clock",
                filter: .lastHour,
                help: "Show logs from the last hour"
            )
        }
    }

    private func quickFilterButton(title: String, icon: String, filter: QuickFilter, help: String) -> some View {
        Button {
            onQuickFilter?(filter)
        } label: {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                if activeQuickFilter == filter {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

#Preview {
    SidebarView(
        selectedSource: .constant(.osLog),
        isStreaming: false,
        onStartStream: {},
        onStopStream: {},
        onQuickFilter: { _ in },
        activeQuickFilter: .errorsOnly
    )
    .frame(width: 220)
}

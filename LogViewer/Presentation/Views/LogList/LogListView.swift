import SwiftUI

struct LogListView: View {
    let entries: [LogEntry]
    @Binding var selection: Set<LogEntry.ID>
    @Binding var sortOrder: [KeyPathComparator<LogEntry>]
    var searchText: String
    var isLoading: Bool
    var onDoubleClick: ((LogEntry) -> Void)?

    var body: some View {
        ZStack {
            if entries.isEmpty && !isLoading {
                ContentUnavailableView(
                    "No Logs",
                    systemImage: "doc.text",
                    description: Text("No log entries match your criteria")
                )
            } else if !entries.isEmpty {
                LogTableWrapper(
                    entries: entries,
                    selection: $selection,
                    sortOrder: $sortOrder,
                    searchText: searchText,
                    onDoubleClick: onDoubleClick
                )
                .opacity(isLoading ? 0.5 : 1.0)
                .allowsHitTesting(!isLoading)
            }

            if isLoading {
                ProgressView("Loading logs...")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(minWidth: 400)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

#Preview {
    LogListView(
        entries: [
            LogEntry(
                timestamp: Date(),
                level: .info,
                subsystem: "com.example.app",
                category: "default",
                process: "Example",
                message: "This is a test log message"
            ),
            LogEntry(
                timestamp: Date().addingTimeInterval(-60),
                level: .error,
                subsystem: "com.example.app",
                category: "network",
                process: "Example",
                message: "Network error occurred"
            )
        ],
        selection: .constant([]),
        sortOrder: .constant([.init(\.timestamp, order: .reverse)]),
        searchText: "",
        isLoading: false
    )
}

import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    @StateObject private var restartViewModel = RestartAnalysisViewModel()
    @StateObject private var filterViewModel = FilterViewModel()
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var selection = Set<LogEntry.ID>()
    @State private var sortOrder: [KeyPathComparator<LogEntry>] = [
        .init(\.timestamp, order: .reverse)
    ]
    @State private var inspectorPresented = false
    @State private var activeQuickFilter: SidebarView.QuickFilter?
    @Environment(\.openWindow) private var openWindow

    private var isRestartMode: Bool {
        viewModel.selectedSource == .systemRestarts
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                selectedSource: $viewModel.selectedSource,
                isStreaming: viewModel.isStreaming,
                onStartStream: { viewModel.startStreaming() },
                onStopStream: { Task { await viewModel.stopStreaming() } },
                onQuickFilter: { quickFilter in
                    applyQuickFilter(quickFilter)
                },
                activeQuickFilter: activeQuickFilter
            )
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } content: {
            if isRestartMode {
                RestartListView(
                    restarts: restartViewModel.restarts,
                    selection: $restartViewModel.selectedRestart,
                    isLoading: restartViewModel.isLoading,
                    statistics: restartViewModel.statistics,
                    patterns: restartViewModel.patterns
                )
                .navigationSplitViewColumnWidth(min: 400, ideal: 600)
            } else {
                LogListView(
                    entries: sortedEntries,
                    selection: $selection,
                    sortOrder: $sortOrder,
                    searchText: viewModel.searchText,
                    isLoading: viewModel.isLoading,
                    onDoubleClick: { entry in
                        viewModel.selectedEntry = entry
                        inspectorPresented = true
                    }
                )
                .navigationSplitViewColumnWidth(min: 400, ideal: 600)
            }
        } detail: {
            if isRestartMode {
                if let restart = restartViewModel.selectedRestart {
                    RestartDetailView(
                        restart: restart,
                        analysis: restartViewModel.selectedAnalysis
                    )
                } else {
                    ContentUnavailableView(
                        "No Restart Selected",
                        systemImage: "bolt.trianglebadge.exclamationmark",
                        description: Text("Select a restart event to view analysis")
                    )
                }
            } else {
                if let entry = selectedEntry {
                    LogDetailView(entry: entry)
                } else {
                    ContentUnavailableView(
                        "No Log Selected",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Select a log entry to view details")
                    )
                }
            }
        }
        .inspector(isPresented: $inspectorPresented) {
            if isRestartMode {
                if let restart = restartViewModel.selectedRestart {
                    RestartDetailView(
                        restart: restart,
                        analysis: restartViewModel.selectedAnalysis
                    )
                    .inspectorColumnWidth(min: 300, ideal: 400, max: 500)
                }
            } else {
                if let entry = selectedEntry {
                    LogDetailView(entry: entry)
                        .inspectorColumnWidth(min: 250, ideal: 300, max: 400)
                }
            }
        }
        .toolbar {
            if isRestartMode {
                ToolbarItem {
                    Button {
                        Task {
                            await restartViewModel.refreshRestarts()
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(restartViewModel.isLoading)
                    .help("Refresh restart history")
                }
            } else {
                FilterToolbar(
                    viewModel: filterViewModel,
                    isStreaming: viewModel.isStreaming,
                    isPaused: viewModel.isPaused,
                    onTogglePause: viewModel.togglePause,
                    onClear: viewModel.clearLogs
                )
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    openWindow(id: "help")
                } label: {
                    Label("Help", systemImage: "questionmark.circle")
                }
                .help("Open LogViewer Help (Cmd+?)")
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search logs...")
        .navigationTitle(navigationTitle)
        .onChange(of: viewModel.selectedSource) { _, newSource in
            if newSource == .systemRestarts {
                Task {
                    await restartViewModel.loadRestarts()
                }
            } else {
                Task {
                    await viewModel.loadLogs()
                }
            }
        }
        .onChange(of: filterViewModel.filter) { _, newFilter in
            viewModel.filter = newFilter
            // Clear quick filter if user manually changed filters
            if let active = activeQuickFilter {
                let matchesQuickFilter: Bool
                switch active {
                case .errorsOnly:
                    matchesQuickFilter = filterViewModel.levels == [.error, .fault]
                case .lastHour:
                    matchesQuickFilter = filterViewModel.timeRangeOption == .lastHour
                }
                if !matchesQuickFilter {
                    activeQuickFilter = nil
                }
            }
        }
        .onChange(of: selection) { _, newSelection in
            if let firstID = newSelection.first {
                viewModel.selectedEntry = viewModel.filteredEntries.first { $0.id == firstID }
            } else {
                viewModel.selectedEntry = nil
            }
        }
        .task {
            await viewModel.loadLogs()
        }
        .alert("Error", isPresented: .constant(currentErrorMessage != nil)) {
            Button("Copy Error") {
                if let error = currentErrorMessage {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(error, forType: .string)
                }
            }
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
                restartViewModel.errorMessage = nil
            }
        } message: {
            Text(currentErrorMessage ?? "")
        }
    }

    private var currentErrorMessage: String? {
        isRestartMode ? restartViewModel.errorMessage : viewModel.errorMessage
    }

    private var selectedEntry: LogEntry? {
        guard let firstID = selection.first else { return nil }
        return viewModel.filteredEntries.first { $0.id == firstID }
    }

    private var sortedEntries: [LogEntry] {
        viewModel.filteredEntries.sorted(using: sortOrder)
    }

    private var navigationTitle: String {
        if isRestartMode {
            var title = "System Restarts"
            if !restartViewModel.restarts.isEmpty {
                title += " (\(restartViewModel.restarts.count))"
            }
            return title
        }

        var title = viewModel.selectedSource.displayName
        if !viewModel.filteredEntries.isEmpty {
            title += " (\(viewModel.filteredEntries.count))"
        }
        if viewModel.isStreaming {
            title += viewModel.isPaused ? " [Paused]" : " [Live]"
        }
        return title
    }

    private func applyQuickFilter(_ quickFilter: SidebarView.QuickFilter) {
        // Toggle off if already active
        if activeQuickFilter == quickFilter {
            activeQuickFilter = nil
            filterViewModel.reset()
            Task {
                await viewModel.loadLogs()
            }
            return
        }

        // Switch to app logs if in restart mode
        if isRestartMode {
            viewModel.selectedSource = .osLog
        }

        activeQuickFilter = quickFilter

        switch quickFilter {
        case .errorsOnly:
            filterViewModel.levels = [.error, .fault]
            filterViewModel.timeRangeOption = .all
        case .lastHour:
            filterViewModel.showAllLevels()
            filterViewModel.timeRangeOption = .lastHour
        }

        Task {
            await viewModel.loadLogs()
        }
    }
}

#Preview {
    MainView()
}

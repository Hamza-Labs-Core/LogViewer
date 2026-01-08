import Foundation
import Combine

@MainActor
final class MainViewModel: ObservableObject {
    @Published var entries: [LogEntry] = []
    @Published var filteredEntries: [LogEntry] = []
    @Published var selectedEntry: LogEntry?
    @Published var selectedSource: LogSource = .osLog
    @Published var isLoading = false
    @Published var isStreaming = false
    @Published var isPaused = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var filter = LogFilter.default
    @Published var statistics: LogStatistics?

    private let processingActor = LogProcessingActor()
    private let searchActor = SearchActor()
    private let streamRepository = ProcessLogRepository()
    private var streamTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupBindings()
        setupNotifications()
    }

    private func setupBindings() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] text in
                Task {
                    await self?.performSearch(text)
                }
            }
            .store(in: &cancellables)

        $filter
            .removeDuplicates()
            .sink { [weak self] filter in
                Task {
                    await self?.applyFilter(filter)
                }
            }
            .store(in: &cancellables)
    }

    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .clearLogs)
            .sink { [weak self] _ in
                self?.clearLogs()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .showAllLevels)
            .sink { [weak self] _ in
                self?.filter.levels = Set(LogLevel.allCases)
                self?.filter.minimumLevel = nil
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .setMinimumLevel)
            .sink { [weak self] notification in
                if let level = notification.object as? LogLevel {
                    self?.filter.minimumLevel = level
                }
            }
            .store(in: &cancellables)
    }

    func loadLogs() async {
        isLoading = true
        errorMessage = nil
        entries = []
        filteredEntries = []
        selectedEntry = nil

        do {
            await processingActor.clearCache()
            let repository = makeRepository(for: selectedSource)

            // Apply a default time filter for system logs to prevent loading millions of entries
            var effectiveFilter = filter
            if selectedSource == .systemLog && effectiveFilter.timeRange == nil {
                effectiveFilter.timeRange = .lastHour
            }

            entries = try await processingActor.fetchAndFilter(from: repository, filter: effectiveFilter)
            filteredEntries = entries
            statistics = await processingActor.statistics(for: entries)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func startStreaming(predicate: String? = nil) {
        guard !isStreaming else { return }

        isStreaming = true
        isPaused = false

        streamTask = Task {
            for await entry in await streamRepository.startStreaming(predicate: predicate) {
                guard !Task.isCancelled else { break }

                if !isPaused {
                    entries.append(entry)
                    if filter.matches(entry) && matchesSearch(entry) {
                        filteredEntries.append(entry)
                    }

                    // Keep memory under control - limit to 10k entries
                    if entries.count > 10_000 {
                        entries.removeFirst(1_000)
                        await applyFilter(filter)
                    }
                }
            }
        }
    }

    func stopStreaming() async {
        streamTask?.cancel()
        streamTask = nil
        await streamRepository.stopStreaming()
        isStreaming = false
        isPaused = false
    }

    func togglePause() {
        isPaused.toggle()
    }

    func clearLogs() {
        entries.removeAll()
        filteredEntries.removeAll()
        selectedEntry = nil
        statistics = nil
    }

    private func performSearch(_ text: String) async {
        if text.isEmpty {
            await applyFilter(filter)
            return
        }

        let results = await searchActor.search(query: text, in: entries) { @MainActor [weak self] batch in
            self?.filteredEntries = batch
        }
        filteredEntries = results
    }

    private func applyFilter(_ filter: LogFilter) async {
        let filtered = await processingActor.filter(entries, with: filter)
        if searchText.isEmpty {
            filteredEntries = filtered
        } else {
            filteredEntries = filtered.filter { matchesSearch($0) }
        }
    }

    private func matchesSearch(_ entry: LogEntry) -> Bool {
        guard !searchText.isEmpty else { return true }
        let query = searchText.lowercased()
        return entry.message.lowercased().contains(query) ||
               entry.process.lowercased().contains(query) ||
               entry.subsystem.lowercased().contains(query)
    }

    private func makeRepository(for source: LogSource) -> any LogRepository {
        switch source {
        case .osLog:
            return OSLogRepository(scope: .currentProcess)
        case .systemLog:
            #if APPSTORE
            return OSLogRepository(scope: .currentProcess)
            #else
            return OSLogRepository(scope: .system)
            #endif
        case .file(let url):
            return FileLogRepository(fileURL: url)
        case .stream:
            return OSLogRepository(scope: .currentProcess)
        case .systemRestarts:
            return OSLogRepository(scope: .currentProcess)
        }
    }
}

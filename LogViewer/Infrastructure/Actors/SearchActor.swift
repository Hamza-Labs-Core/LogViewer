import Foundation

actor SearchActor {
    private var currentTask: Task<Void, Never>?

    func search(
        query: String,
        in entries: [LogEntry],
        batchSize: Int = 5000,
        onBatch: @escaping @Sendable ([LogEntry]) -> Void
    ) async -> [LogEntry] {
        currentTask?.cancel()

        var allResults: [LogEntry] = []
        let lowercasedQuery = query.lowercased()

        let task = Task {
            for startIndex in stride(from: 0, to: entries.count, by: batchSize) {
                if Task.isCancelled { break }

                let endIndex = min(startIndex + batchSize, entries.count)
                let batch = Array(entries[startIndex..<endIndex])

                let batchResults = batch.filter { entry in
                    matches(entry: entry, query: lowercasedQuery)
                }

                allResults.append(contentsOf: batchResults)

                if !batchResults.isEmpty {
                    await MainActor.run {
                        onBatch(allResults)
                    }
                }

                await Task.yield()
            }
        }

        currentTask = task
        await task.value

        return allResults
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }

    private func matches(entry: LogEntry, query: String) -> Bool {
        entry.message.lowercased().contains(query) ||
        entry.process.lowercased().contains(query) ||
        entry.subsystem.lowercased().contains(query) ||
        entry.category.lowercased().contains(query)
    }

    func highlightMatches(in text: String, query: String) -> [(range: Range<String.Index>, isMatch: Bool)] {
        guard !query.isEmpty else {
            return [(text.startIndex..<text.endIndex, false)]
        }

        var results: [(Range<String.Index>, Bool)] = []
        var currentIndex = text.startIndex

        let lowercasedText = text.lowercased()
        let lowercasedQuery = query.lowercased()

        while currentIndex < text.endIndex {
            if let matchRange = lowercasedText.range(of: lowercasedQuery, range: currentIndex..<text.endIndex) {
                let originalMatchStart = text.index(text.startIndex, offsetBy: lowercasedText.distance(from: lowercasedText.startIndex, to: matchRange.lowerBound))
                let originalMatchEnd = text.index(text.startIndex, offsetBy: lowercasedText.distance(from: lowercasedText.startIndex, to: matchRange.upperBound))

                if currentIndex < originalMatchStart {
                    results.append((currentIndex..<originalMatchStart, false))
                }

                results.append((originalMatchStart..<originalMatchEnd, true))
                currentIndex = originalMatchEnd
            } else {
                if currentIndex < text.endIndex {
                    results.append((currentIndex..<text.endIndex, false))
                }
                break
            }
        }

        return results
    }
}

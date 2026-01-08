import Foundation
import Combine

@MainActor
final class RestartAnalysisViewModel: ObservableObject {
    @Published var restarts: [SystemRestart] = []
    @Published var selectedRestart: SystemRestart?
    @Published var selectedAnalysis: RestartAnalysis?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var statistics: RestartStatistics?
    @Published var patterns: [String] = []

    private let analysisActor = PanicAnalysisActor()
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupBindings()
    }

    private func setupBindings() {
        $selectedRestart
            .sink { [weak self] restart in
                guard let restart = restart else {
                    self?.selectedAnalysis = nil
                    return
                }
                Task {
                    await self?.analyzeRestart(restart)
                }
            }
            .store(in: &cancellables)
    }

    func loadRestarts() async {
        isLoading = true
        errorMessage = nil

        do {
            restarts = try await analysisActor.fetchRestarts(forceRefresh: false)
            statistics = await analysisActor.statistics(for: restarts)
            patterns = await analysisActor.findPattern(in: restarts)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func refreshRestarts() async {
        isLoading = true
        errorMessage = nil

        do {
            await analysisActor.clearCache()
            restarts = try await analysisActor.fetchRestarts(forceRefresh: true)
            statistics = await analysisActor.statistics(for: restarts)
            patterns = await analysisActor.findPattern(in: restarts)

            if let selected = selectedRestart {
                await analyzeRestart(selected)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func analyzeRestart(_ restart: SystemRestart) async {
        selectedAnalysis = await analysisActor.analyze(restart)
    }

    func selectRestart(_ restart: SystemRestart) {
        selectedRestart = restart
    }

    func clearSelection() {
        selectedRestart = nil
        selectedAnalysis = nil
    }
}

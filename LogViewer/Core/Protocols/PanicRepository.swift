import Foundation

protocol PanicRepository: Sendable {
    func fetchPanics() async throws -> [KernelPanic]
    func fetchCrashReports(around date: Date, windowMinutes: Int) async throws -> [CrashReport]
    func fetchSystemRestarts() async throws -> [SystemRestart]
}

enum PanicRepositoryError: Error, LocalizedError {
    case directoryNotFound(URL)
    case accessDenied
    case parsingFailed(String)
    case noData

    var errorDescription: String? {
        switch self {
        case .directoryNotFound(let url):
            return "Diagnostic reports directory not found: \(url.path)"
        case .accessDenied:
            return "Access to diagnostic reports was denied. Check permissions in System Settings > Privacy & Security > Full Disk Access."
        case .parsingFailed(let message):
            return "Failed to parse diagnostic report: \(message)"
        case .noData:
            return "No panic or crash data found"
        }
    }
}

import Foundation

actor ProcessLogRepository: LogStreamer {
    private var process: Process?
    private var outputPipe: Pipe?
    private var continuation: AsyncStream<LogEntry>.Continuation?

    func startStreaming(predicate: String?) -> AsyncStream<LogEntry> {
        AsyncStream { continuation in
            self.continuation = continuation

            Task {
                await self.startProcess(predicate: predicate, continuation: continuation)
            }

            continuation.onTermination = { @Sendable _ in
                Task {
                    await self.stopStreaming()
                }
            }
        }
    }

    func stopStreaming() async {
        process?.terminate()
        process = nil
        outputPipe = nil
        continuation?.finish()
        continuation = nil
    }

    private func startProcess(predicate: String?, continuation: AsyncStream<LogEntry>.Continuation) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/log")

        var arguments = ["stream", "--style", "json", "--level", "debug"]
        if let predicate = predicate, !predicate.isEmpty {
            arguments.append(contentsOf: ["--predicate", predicate])
        }
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        var buffer = Data()

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }

            buffer.append(data)

            while let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                let lineData = buffer[buffer.startIndex..<newlineIndex]
                buffer = Data(buffer[buffer.index(after: newlineIndex)...])

                if let entry = self?.parseJSONLogEntry(lineData) {
                    continuation.yield(entry)
                }
            }
        }

        process.terminationHandler = { _ in
            continuation.finish()
        }

        do {
            try process.run()
            self.process = process
            self.outputPipe = pipe
        } catch {
            continuation.finish()
        }
    }

    private nonisolated func parseJSONLogEntry(_ data: Data) -> LogEntry? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let timestamp: Date
        if let timestampString = json["timestamp"] as? String {
            timestamp = parseTimestamp(timestampString) ?? Date()
        } else {
            timestamp = Date()
        }

        let level = parseLevel(json["messageType"] as? String)
        let subsystem = json["subsystem"] as? String ?? ""
        let category = json["category"] as? String ?? ""
        let processPath = json["processImagePath"] as? String ?? ""
        let process = URL(fileURLWithPath: processPath).lastPathComponent
        let processID = json["processID"] as? Int32 ?? 0
        let threadID = json["threadID"] as? UInt64 ?? 0
        let message = json["eventMessage"] as? String ?? ""

        return LogEntry(
            timestamp: timestamp,
            level: level,
            subsystem: subsystem,
            category: category,
            process: process,
            processIdentifier: processID,
            threadIdentifier: threadID,
            message: message,
            source: .stream
        )
    }

    private nonisolated func parseTimestamp(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }

    private nonisolated func parseLevel(_ string: String?) -> LogLevel {
        guard let string = string?.lowercased() else { return .info }

        switch string {
        case "debug":
            return .debug
        case "info":
            return .info
        case "default", "notice":
            return .notice
        case "error":
            return .error
        case "fault":
            return .fault
        default:
            return .info
        }
    }
}

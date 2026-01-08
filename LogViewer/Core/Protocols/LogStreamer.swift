import Foundation

protocol LogStreamer: Sendable {
    func startStreaming(predicate: String?) -> AsyncStream<LogEntry>
    func stopStreaming() async
}

protocol LogStreamDelegate: AnyObject, Sendable {
    func logStreamer(_ streamer: any LogStreamer, didReceiveEntry entry: LogEntry)
    func logStreamer(_ streamer: any LogStreamer, didFailWithError error: Error)
}

import Foundation

enum MicAccessState: Equatable, Sendable {
    case notDetermined
    case granted
    case denied
}

/// The value type that crosses the capture seam — no `AVAudioPCMBuffer`
/// ever does (decisions/0001).
struct CaptureBuffer: Sendable {
    let samples: [Float]
    let sampleRate: Double

    var frameCount: Int { samples.count }
    var duration: TimeInterval { Double(samples.count) / sampleRate }
}

/// All microphone access crosses this seam. Buffers exist only in flight:
/// consumers derive what they need and discard them — nothing is ever
/// written (decisions/0001).
protocol CaptureService: Sendable {
    func accessState() async -> MicAccessState
    /// Prompts the user; never called on launch — only from an explicit
    /// record action.
    func requestAccess() async -> MicAccessState
    /// Starts the mic stream; buffers flow until `stopCapture()` or a
    /// stream failure ends it.
    func startCapture() async throws -> AsyncThrowingStream<CaptureBuffer, any Error>
    func stopCapture() async
}

import Foundation

actor FixtureCaptureService: CaptureService {
    private var state: MicAccessState
    private let accessRequestResult: MicAccessState
    private let buffers: [CaptureBuffer]
    private let streamError: (any Error)?
    private var continuation: AsyncThrowingStream<CaptureBuffer, any Error>.Continuation?
    private(set) var accessRequests = 0
    private(set) var startCount = 0
    private(set) var stopCount = 0

    init(
        buffers: [CaptureBuffer] = [],
        state: MicAccessState = .granted,
        accessRequestResult: MicAccessState = .granted,
        streamError: (any Error)? = nil
    ) {
        self.buffers = buffers
        self.state = state
        self.accessRequestResult = accessRequestResult
        self.streamError = streamError
    }

    func accessState() async -> MicAccessState { state }

    func requestAccess() async -> MicAccessState {
        accessRequests += 1
        if state == .notDetermined {
            state = accessRequestResult
        }
        return state
    }

    /// Yields every fixture buffer up front, then leaves the stream open
    /// until `stopCapture()` — or ends it with the injected error.
    func startCapture() async throws -> AsyncThrowingStream<CaptureBuffer, any Error> {
        startCount += 1
        let (stream, continuation) = AsyncThrowingStream<CaptureBuffer, any Error>.makeStream()
        for buffer in buffers {
            continuation.yield(buffer)
        }
        if let streamError {
            continuation.finish(throwing: streamError)
        } else {
            self.continuation = continuation
        }
        return stream
    }

    func stopCapture() async {
        stopCount += 1
        continuation?.finish()
        continuation = nil
    }
}

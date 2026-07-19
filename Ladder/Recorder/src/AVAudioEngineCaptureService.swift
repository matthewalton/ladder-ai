import AVFoundation

/// The live implementation — exercised by humans only, never constructed
/// in tests (AGENTS.md).
actor AVAudioEngineCaptureService: CaptureService {
    private var engine: AVAudioEngine?
    private var continuation: AsyncThrowingStream<CaptureBuffer, any Error>.Continuation?

    func accessState() async -> MicAccessState {
        Self.map(AVCaptureDevice.authorizationStatus(for: .audio))
    }

    func requestAccess() async -> MicAccessState {
        await AVCaptureDevice.requestAccess(for: .audio) ? .granted : .denied
    }

    func startCapture() async throws -> AsyncThrowingStream<CaptureBuffer, any Error> {
        await stopCapture()
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        // Dropping stale buffers under pressure only ever costs meter
        // frames — nothing downstream stores audio (decisions/0001).
        let (stream, continuation) = AsyncThrowingStream<CaptureBuffer, any Error>.makeStream(
            bufferingPolicy: .bufferingNewest(8)
        )
        input.installTap(onBus: 0, bufferSize: 4_096, format: format) { buffer, _ in
            guard let channel = buffer.floatChannelData else { return }
            let samples = Array(
                UnsafeBufferPointer(start: channel[0], count: Int(buffer.frameLength))
            )
            continuation.yield(
                CaptureBuffer(samples: samples, sampleRate: buffer.format.sampleRate)
            )
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            continuation.finish(throwing: error)
            throw error
        }
        self.engine = engine
        self.continuation = continuation
        return stream
    }

    func stopCapture() async {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        continuation?.finish()
        continuation = nil
    }

    private static func map(_ status: AVAuthorizationStatus) -> MicAccessState {
        switch status {
        case .authorized: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }
}

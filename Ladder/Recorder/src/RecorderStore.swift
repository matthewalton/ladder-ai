import Foundation

enum RecorderState: Equatable, Sendable {
    case idle
    case awaitingConsent
    case denied
    case recording
}

@MainActor
@Observable
final class RecorderStore {
    static let consentKey = "captureConsentGranted"

    private let service: any CaptureService
    private let defaults: UserDefaults
    @ObservationIgnored private var captureTask: Task<Void, Never>?

    private(set) var state: RecorderState = .idle
    private(set) var meterLevel: Double = 0
    private(set) var elapsed: TimeInterval = 0
    private(set) var processedBuffers = 0
    /// Surfaced quietly in the popover; cleared when the next capture starts.
    private(set) var captureFailed = false

    init(service: any CaptureService, defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
    }

    var hasConsent: Bool {
        defaults.bool(forKey: Self.consentKey)
    }

    /// The visible recording indicator ([RECORDER-11]): the recording
    /// symbol exactly while a capture is live.
    var menuBarSymbolName: String {
        state == .recording ? "record.circle.fill" : "waveform.circle"
    }

    /// The record action runs its gates in order: consent (decisions/0002)
    /// first, sober of any permission dialog, then mic access.
    func record() async {
        guard state != .recording else { return }
        guard hasConsent else {
            state = .awaitingConsent
            return
        }
        await startCapture()
    }

    /// Accepting is what leads on to the mic-access gate and the session.
    func acceptConsent() async {
        defaults.set(true, forKey: Self.consentKey)
        await startCapture()
    }

    /// Declining writes nothing — the next record action asks again
    /// (decisions/0002).
    func declineConsent() {
        guard state == .awaitingConsent else { return }
        state = .idle
    }

    func stop() async {
        guard state == .recording else { return }
        await service.stopCapture()
        captureTask = nil
        state = .idle
        meterLevel = 0
    }

    private func startCapture() async {
        var access = await service.accessState()
        if access == .notDetermined {
            access = await service.requestAccess()
        }
        guard access == .granted else {
            state = .denied
            return
        }
        do {
            let stream = try await service.startCapture()
            state = .recording
            captureFailed = false
            meterLevel = 0
            elapsed = 0
            processedBuffers = 0
            captureTask = Task { [weak self] in
                do {
                    for try await buffer in stream {
                        guard let self, self.state == .recording else { return }
                        self.consume(buffer)
                    }
                } catch {
                    self?.streamFailed()
                }
            }
        } catch {
            state = .idle
        }
    }

    /// The buffer dies here: one level derived, the duration counted, and
    /// nothing retained or written (decisions/0001).
    private func consume(_ buffer: CaptureBuffer) {
        meterLevel = MeterLevel.level(of: buffer)
        elapsed += buffer.duration
        processedBuffers += 1
    }

    private func streamFailed() {
        guard state == .recording else { return }
        captureFailed = true
        state = .idle
        meterLevel = 0
    }
}

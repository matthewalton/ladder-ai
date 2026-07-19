import Foundation
import Testing

@testable import Ladder

@MainActor
struct RecorderFlowTests {
    private struct Harness {
        let store: RecorderStore
        let service: FixtureCaptureService
        let defaults: UserDefaults
        let suiteName: String

        func cleanUp() {
            defaults.removePersistentDomain(forName: suiteName)
        }
    }

    private func makeHarness(
        buffers: [CaptureBuffer] = [],
        state: MicAccessState = .granted,
        accessRequestResult: MicAccessState = .granted,
        streamError: (any Error)? = nil,
        consented: Bool = true
    ) -> Harness {
        let suiteName = "RecorderFlowTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        if consented {
            defaults.set(true, forKey: RecorderStore.consentKey)
        }
        let service = FixtureCaptureService(
            buffers: buffers,
            state: state,
            accessRequestResult: accessRequestResult,
            streamError: streamError
        )
        let store = RecorderStore(service: service, defaults: defaults)
        return Harness(store: store, service: service, defaults: defaults, suiteName: suiteName)
    }

    private func buffer(
        amplitude: Float, frames: Int = 4_800, sampleRate: Double = 48_000
    ) -> CaptureBuffer {
        CaptureBuffer(
            samples: [Float](repeating: amplitude, count: frames), sampleRate: sampleRate
        )
    }

    /// The consume loop runs as a main-actor Task; yielding lets it drain
    /// the already-queued fixture buffers deterministically.
    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<10_000 where !condition() {
            await Task.yield()
        }
    }

    // MARK: - Tracer

    @Test("[RECORDER-1] starting a capture from the menu bar streams meter levels and elapsed time")
    func startingCaptureStreamsLevelsAndElapsed() async throws {
        let harness = makeHarness(buffers: [
            buffer(amplitude: 0.5), buffer(amplitude: 0.5), buffer(amplitude: 0.5),
        ])
        defer { harness.cleanUp() }

        await harness.store.record()

        #expect(harness.store.state == .recording)
        await waitUntil { harness.store.processedBuffers == 3 }
        #expect(harness.store.meterLevel > 0)
        // Three 4 800-frame buffers at 48 kHz are 0.3 s of audio.
        #expect(abs(harness.store.elapsed - 0.3) < 0.000_1)
    }

    // MARK: - Stop

    @Test("[RECORDER-2] stopping a capture returns the recorder to idle with the meter at zero")
    func stoppingCaptureReturnsToIdle() async throws {
        let harness = makeHarness(buffers: [buffer(amplitude: 0.5), buffer(amplitude: 0.5)])
        defer { harness.cleanUp() }

        await harness.store.record()
        await waitUntil { harness.store.processedBuffers == 2 }
        await harness.store.stop()

        #expect(harness.store.state == .idle)
        #expect(harness.store.meterLevel == 0)
        #expect(await harness.service.stopCount == 1)

        // A new capture starts its clock from zero.
        await harness.store.record()
        #expect(harness.store.state == .recording)
        #expect(harness.store.elapsed == 0)
    }

    // MARK: - Privacy

    @Test("[RECORDER-3] a capture session writes no file")
    func captureSessionWritesNoFile() async throws {
        let fileManager = FileManager.default
        let watched =
            [fileManager.temporaryDirectory]
            + fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        func snapshot() -> Set<String> {
            Set(
                watched.flatMap { directory in
                    ((try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? [])
                        .map { directory.path + "/" + $0 }
                }
            )
        }

        let before = snapshot()
        let harness = makeHarness(buffers: [buffer(amplitude: 0.5), buffer(amplitude: 0.5)])
        defer { harness.cleanUp() }
        await harness.store.record()
        await waitUntil { harness.store.processedBuffers == 2 }
        await harness.store.stop()

        let created = snapshot().subtracting(before)
        #expect(created.isEmpty)
    }

    // MARK: - Consent

    @Test("[RECORDER-5] the first record action presents the consent screen instead of starting a capture")
    func firstRecordActionAwaitsConsent() async throws {
        let harness = makeHarness(buffers: [buffer(amplitude: 0.5)], consented: false)
        defer { harness.cleanUp() }

        await harness.store.record()

        #expect(harness.store.state == .awaitingConsent)
        #expect(await harness.service.startCount == 0)
    }

    @Test("[RECORDER-6] accepted consent persists across app relaunches")
    func acceptedConsentPersists() async throws {
        let harness = makeHarness(buffers: [buffer(amplitude: 0.5)], consented: false)
        defer { harness.cleanUp() }

        await harness.store.record()
        #expect(harness.store.state == .awaitingConsent)
        await harness.store.acceptConsent()
        #expect(harness.store.state == .recording)
        await harness.store.stop()

        // A second store over the same suite is the relaunch stand-in:
        // straight to recording, no consent step.
        let relaunched = RecorderStore(service: harness.service, defaults: harness.defaults)
        await relaunched.record()
        #expect(relaunched.state == .recording)
        #expect(await harness.service.startCount == 2)
    }

    @Test("[RECORDER-7] declining consent leaves the recorder idle with no capture started")
    func decliningConsentLeavesIdle() async throws {
        let harness = makeHarness(buffers: [buffer(amplitude: 0.5)], consented: false)
        defer { harness.cleanUp() }

        await harness.store.record()
        #expect(harness.store.state == .awaitingConsent)
        harness.store.declineConsent()

        #expect(harness.store.state == .idle)
        #expect(harness.store.hasConsent == false)
        #expect(await harness.service.startCount == 0)

        // Declining is "not now", not "never ask": the next record action
        // presents the consent screen again.
        await harness.store.record()
        #expect(harness.store.state == .awaitingConsent)
    }

    // MARK: - Mic access

    @Test("[RECORDER-8] a record action with undetermined mic access requests access through the seam")
    func undeterminedAccessIsRequested() async throws {
        let harness = makeHarness(
            buffers: [buffer(amplitude: 0.5)],
            state: .notDetermined,
            accessRequestResult: .granted
        )
        defer { harness.cleanUp() }

        await harness.store.record()

        #expect(await harness.service.accessRequests == 1)
        #expect(harness.store.state == .recording)

        // A denied answer to the request lands in the denied state.
        let refused = makeHarness(state: .notDetermined, accessRequestResult: .denied)
        defer { refused.cleanUp() }
        await refused.store.record()
        #expect(refused.store.state == .denied)
        #expect(await refused.service.startCount == 0)
    }

    @Test("[RECORDER-9] a record action with denied mic access surfaces the denied state and starts no capture")
    func deniedAccessSurfacesDeniedState() async throws {
        let harness = makeHarness(buffers: [buffer(amplitude: 0.5)], state: .denied)
        defer { harness.cleanUp() }

        await harness.store.record()

        #expect(harness.store.state == .denied)
        #expect(await harness.service.startCount == 0)
        // Denied is a state, never a prompt: access was already answered,
        // so the record action asks nothing.
        #expect(await harness.service.accessRequests == 0)
    }

    // MARK: - Indicator

    @Test("[RECORDER-11] the menu bar icon shows the recording symbol while a capture is live")
    func menuBarIconShowsRecordingSymbol() async throws {
        let harness = makeHarness(buffers: [buffer(amplitude: 0.5)])
        defer { harness.cleanUp() }

        #expect(harness.store.menuBarSymbolName == "waveform.circle")
        await harness.store.record()
        #expect(harness.store.menuBarSymbolName == "record.circle.fill")
        await harness.store.stop()
        #expect(harness.store.menuBarSymbolName == "waveform.circle")
    }

    // MARK: - Stream failure

    @Test("[RECORDER-12] a capture stream error returns the recorder to idle")
    func streamErrorReturnsToIdle() async throws {
        struct EngineDied: Error {}
        let harness = makeHarness(
            buffers: [buffer(amplitude: 0.5)], streamError: EngineDied()
        )
        defer { harness.cleanUp() }

        await harness.store.record()
        await waitUntil { harness.store.state == .idle }

        #expect(harness.store.state == .idle)
        #expect(harness.store.meterLevel == 0)
        #expect(harness.store.captureFailed)

        // The record action works again immediately.
        await harness.store.record()
        #expect(await harness.service.startCount == 2)
    }
}

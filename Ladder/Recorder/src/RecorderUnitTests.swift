import Foundation
import Testing

@testable import Ladder

struct RecorderUnitTests {
    @Test("[RECORDER-4] a capture buffer's meter level equals its RMS amplitude clamped to 0–1")
    func meterLevelIsClampedRMS() {
        let constant = CaptureBuffer(
            samples: [Float](repeating: 0.5, count: 4_800), sampleRate: 48_000
        )
        #expect(abs(MeterLevel.level(of: constant) - 0.5) < 0.000_001)

        let silence = CaptureBuffer(
            samples: [Float](repeating: 0, count: 4_800), sampleRate: 48_000
        )
        #expect(MeterLevel.level(of: silence) == 0)

        // A full-scale square wave alternates ±1.0 — RMS exactly 1.
        let square = CaptureBuffer(
            samples: (0..<4_800).map { $0 % 2 == 0 ? Float(1) : Float(-1) },
            sampleRate: 48_000
        )
        #expect(abs(MeterLevel.level(of: square) - 1.0) < 0.000_001)

        // A full-scale sine's RMS is 1/√2 ≈ 0.707.
        let sine = CaptureBuffer(
            samples: (0..<4_800).map { Float(sin(Double($0) / 64 * 2 * .pi)) },
            sampleRate: 48_000
        )
        #expect(abs(MeterLevel.level(of: sine) - 0.707_1) < 0.001)

        // An over-driven float buffer clamps to 1.
        let overdriven = CaptureBuffer(
            samples: [Float](repeating: 1.5, count: 4_800), sampleRate: 48_000
        )
        #expect(MeterLevel.level(of: overdriven) == 1)

        let empty = CaptureBuffer(samples: [], sampleRate: 48_000)
        #expect(MeterLevel.level(of: empty) == 0)
    }

    @Test("[RECORDER-10] the app bundle carries the microphone usage description")
    func usageDescriptionIsPresent() {
        // Tests run in the app host, so Bundle.main is Ladder.app — the same
        // Info dictionary the permission prompt reads.
        let copy = Bundle.main.object(
            forInfoDictionaryKey: "NSMicrophoneUsageDescription"
        ) as? String
        #expect(copy?.isEmpty == false)
    }
}

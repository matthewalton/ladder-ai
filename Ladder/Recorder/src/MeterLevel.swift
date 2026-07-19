import Foundation

/// A pure helper, so any consumer of the seam can derive levels and the
/// seam never needs a levels API (decisions/0001).
enum MeterLevel {
    /// RMS amplitude of the buffer's samples, clamped to 0–1.
    static func level(of buffer: CaptureBuffer) -> Double {
        guard !buffer.samples.isEmpty else { return 0 }
        let sumOfSquares = buffer.samples.reduce(0.0) { $0 + Double($1) * Double($1) }
        let rms = (sumOfSquares / Double(buffer.samples.count)).squareRoot()
        return min(rms, 1)
    }
}

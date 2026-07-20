import Foundation

/// One row of the Stage detail's readout.
struct TranscriptReadoutRow: Equatable, Identifiable {
    let id: Int
    let speaker: SpeakerAttribution
    let text: String
    /// "M:SS", or "H:MM:SS" from the hour up; nil when the segment carries
    /// no start time — never a placeholder (decisions/0002).
    let timeLabel: String?
}

/// Pure derivation — segments in, rows out — so the view stays thin.
enum TranscriptReadoutModel {
    static func rows(for segments: [Segment]) -> [TranscriptReadoutRow] {
        segments.enumerated().map { index, segment in
            TranscriptReadoutRow(
                id: index,
                speaker: segment.speaker,
                text: segment.text,
                timeLabel: segment.tStart.map(timeLabel(seconds:))
            )
        }
    }

    static func timeLabel(seconds: Double) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}

import Foundation
import SwiftData

enum SpeakerAttribution: String, Codable, Hashable, Sendable {
    case me
    case them
}

struct Segment: Codable, Hashable, Sendable {
    var speaker: SpeakerAttribution
    var text: String
    var tStart: Double?
    var tEnd: Double?

    init(speaker: SpeakerAttribution, text: String, tStart: Double? = nil, tEnd: Double? = nil) {
        self.speaker = speaker
        self.text = text
        self.tStart = tStart
        self.tEnd = tEnd
    }
}

/// Imported (Granola) and natively-captured transcripts share this one shape
/// (ADR 0002), so nothing downstream can tell them apart.
@Model
final class Transcript {
    var recordedAt: Date
    /// 0 means unknown, not instant (decisions/0002).
    var durationSec: Int
    var sourceApp: String?
    var notesSummary: String?
    var segments: [Segment]
    var stage: Stage?

    init(
        recordedAt: Date,
        durationSec: Int = 0,
        sourceApp: String? = nil,
        notesSummary: String? = nil,
        segments: [Segment] = []
    ) {
        self.recordedAt = recordedAt
        self.durationSec = durationSec
        self.sourceApp = sourceApp
        self.notesSummary = notesSummary
        self.segments = segments
    }
}

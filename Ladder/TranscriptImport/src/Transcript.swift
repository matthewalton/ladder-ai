import Foundation
import SwiftData

/// Which side of the table a Segment belongs to. Two values only — no named
/// speakers are stored (decisions/0001).
enum SpeakerAttribution: String, Codable, Hashable, Sendable {
    case me
    case them
}

/// One speaker turn. A Codable value type on the Transcript, not a @Model.
/// Times are optional: they parse when the imported text carries them and
/// stay nil otherwise — nothing is invented (decisions/0002).
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

/// The record of one interview conversation, attached to a Stage. Imported
/// (Granola) and natively-captured transcripts share this one shape
/// (ADR 0002), so nothing downstream can tell them apart.
@Model
final class Transcript {
    var recordedAt: Date
    /// 0 means unknown, not instant (decisions/0002).
    var durationSec: Int
    var sourceApp: String?
    /// Granola's AI notes overview, verbatim; nil when none was pasted
    /// (decisions/0005).
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

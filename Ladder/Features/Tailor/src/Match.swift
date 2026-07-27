import Foundation
import SwiftData

/// The confirmed correspondence between one Application's job description
/// and the Profile (root `CONTEXT.md`: Match): which of the JD's asks the
/// Tag vocabulary covers, and which it doesn't. Written only by the JD scan
/// and replaced wholesale by each one — it tracks the pool, never freezes
/// (decisions/0011). The immutable record of what was sent is the CV
/// snapshot, not this.
@Model
final class Match {
    /// Live references into the shared pool — renames propagate, deleting a
    /// SkillTag removes it here without resurrecting a gap ([TAILOR-39],
    /// [TAILOR-40]).
    @Relationship
    var matchedTags: [SkillTag]
    /// The JD's asks no Tag — primary name or Alias — matches, verbatim.
    var vocabularyGaps: [String]
    var scannedAt: Date
    var application: Application?

    init(matchedTags: [SkillTag] = [], vocabularyGaps: [String] = [], scannedAt: Date = .now) {
        self.matchedTags = matchedTags
        self.vocabularyGaps = vocabularyGaps
        self.scannedAt = scannedAt
    }
}

extension Match {
    /// The deterministic Match score (root ADR 0005; decisions/0012):
    /// coverage of the JD's asks, derived on read and never stored. Nil when
    /// the Match has no asks at all — no score beats a hollow one.
    var score: Int? {
        Match.score(matched: matchedTags.count, gaps: vocabularyGaps.count)
    }

    /// matched ÷ (matched + gaps) as a whole percentage, rounded half-up.
    static func score(matched: Int, gaps: Int) -> Int? {
        let total = matched + gaps
        guard total > 0 else { return nil }
        return Int((Double(matched) / Double(total) * 100).rounded())
    }
}

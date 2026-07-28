import Foundation
import SwiftData

@Model
final class Match {
    @Relationship
    var matchedTags: [SkillTag]
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
    var score: Int? {
        Match.score(matched: matchedTags.count, gaps: vocabularyGaps.count)
    }

    static func score(matched: Int, gaps: Int) -> Int? {
        let total = matched + gaps
        guard total > 0 else { return nil }
        return Int((Double(matched) / Double(total) * 100).rounded())
    }
}

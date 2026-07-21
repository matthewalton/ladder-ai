import Foundation

/// Judges expanded bullets only — a review never adds or removes achievements
/// from the selection.
@MainActor
@Observable
final class TailorReview {
    let items: [ReviewedBullet]
    /// Carried verbatim into the outcome — generated per application, never
    /// stored (decisions/0006).
    let summary: String
    let gaps: [String]
    let rationale: String

    init(result: TailorResult, achievementsByID: [String: Achievement]) {
        // Ids were validated against the payload map before construction,
        // so every selection resolves.
        items = result.selections.compactMap { selection in
            achievementsByID[selection.achievementID].map {
                ReviewedBullet(achievement: $0, bullet: selection.bullet)
            }
        }
        summary = result.summary
        gaps = result.gaps
        rationale = result.rationale
    }

    /// The input cv-export consumes.
    var outcome: ReviewedOutcome {
        ReviewedOutcome(
            items: items.map {
                ReviewedOutcome.Item(
                    canonicalText: $0.achievement.text,
                    text: $0.accepted ? $0.bullet : $0.achievement.text
                )
            },
            summary: summary,
            gaps: gaps,
            rationale: rationale
        )
    }
}

/// Plain values — holding one never retains the SwiftData models it was
/// derived from.
struct ReviewedOutcome: Equatable, Sendable {
    struct Item: Equatable, Sendable {
        var canonicalText: String
        var text: String
    }

    var items: [Item]
    var summary: String = ""
    var gaps: [String]
    var rationale: String
}

@MainActor
@Observable
final class ReviewedBullet: Identifiable {
    let achievement: Achievement
    /// Rejecting keeps the selection; the CV falls back to the brief
    /// canonical point — the canon stays the user's.
    let bullet: String
    var accepted = true

    init(achievement: Achievement, bullet: String) {
        self.achievement = achievement
        self.bullet = bullet
    }
}

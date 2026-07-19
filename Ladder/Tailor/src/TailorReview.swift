import Foundation

/// Judges rewordings only — a review never adds or removes achievements
/// from the selection.
@MainActor
@Observable
final class TailorReview {
    let items: [ReviewedRephrasing]
    let gaps: [String]
    let rationale: String

    init(result: TailorResult, achievementsByID: [String: Achievement]) {
        // Ids were validated against the payload map before construction,
        // so every selection resolves.
        items = result.selections.compactMap { selection in
            achievementsByID[selection.achievementID].map {
                ReviewedRephrasing(achievement: $0, rephrasing: selection.rephrasing)
            }
        }
        gaps = result.gaps
        rationale = result.rationale
    }

    /// The input cv-export consumes.
    var outcome: ReviewedOutcome {
        ReviewedOutcome(
            items: items.map {
                ReviewedOutcome.Item(
                    canonicalText: $0.achievement.text,
                    text: $0.accepted ? $0.rephrasing : $0.achievement.text
                )
            },
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
    var gaps: [String]
    var rationale: String
}

@MainActor
@Observable
final class ReviewedRephrasing: Identifiable {
    let achievement: Achievement
    let rephrasing: String
    var accepted = true

    init(achievement: Achievement, rephrasing: String) {
        self.achievement = achievement
        self.rephrasing = rephrasing
    }
}

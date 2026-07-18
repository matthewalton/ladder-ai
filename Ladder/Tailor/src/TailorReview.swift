import Foundation

/// The review (slice CONTEXT.md): side-by-side accept/reject over each
/// rephrasing, producing the reviewed outcome. It judges rewordings only —
/// it never adds or removes achievements from the selection.
@MainActor
@Observable
final class TailorReview {
    let items: [ReviewedRephrasing]
    let gaps: [String]
    let rationale: String

    init(result: TailorResult, achievementsByID: [String: Achievement]) {
        // Ids were validated against the payload map ([TAILOR-8]) before a
        // review is constructed, so every selection resolves.
        items = result.selections.compactMap { selection in
            achievementsByID[selection.achievementID].map {
                ReviewedRephrasing(achievement: $0, rephrasing: selection.rephrasing)
            }
        }
        gaps = result.gaps
        rationale = result.rationale
    }

    /// The reviewed outcome (slice CONTEXT.md): per selected achievement,
    /// the accepted rephrasing or the canonical text ([TAILOR-13],
    /// [TAILOR-14]). The input cv-export will consume; transient like
    /// everything else here.
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

/// The post-review result. Plain values — holding it never retains the
/// SwiftData models it was derived from.
struct ReviewedOutcome: Equatable, Sendable {
    struct Item: Equatable, Sendable {
        var canonicalText: String
        var text: String
    }

    var items: [Item]
    var gaps: [String]
    var rationale: String
}

/// One selected achievement in review: canonical text beside the proposed
/// rephrasing (SPEC.md [TAILOR-11]), entering as accepted ([TAILOR-12]).
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

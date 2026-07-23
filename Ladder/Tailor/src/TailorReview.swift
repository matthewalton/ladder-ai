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

    /// Whole projects the result selected, in selection order — carried
    /// as-is, never expanded (decisions/0007).
    let selectedProjects: [Project]

    /// The per-CV skill grouping, verbatim from the result (decisions/0009)
    /// — cv-export's skills table renders it ([CVEXPORT-23]).
    let skillCategories: [SkillCategory]

    init(
        result: TailorResult,
        achievementsByID: [String: Achievement],
        projectsByID: [String: Project] = [:]
    ) {
        // Ids were validated against the payload maps before construction,
        // so every selection resolves.
        items = result.selections.compactMap { selection in
            achievementsByID[selection.achievementID].map {
                ReviewedBullet(achievement: $0, bullet: selection.bullet)
            }
        }
        selectedProjects = result.projects.compactMap { projectsByID[$0] }
        skillCategories = result.skillCategories
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
            projects: selectedProjects.map {
                ReviewedOutcome.Project(
                    name: $0.name,
                    link: $0.link,
                    details: $0.details,
                    tags: $0.skills.map(\.name).sorted()
                )
            },
            skillCategories: skillCategories,
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

    /// A selected whole project — description and Tags verbatim from the
    /// Profile (decisions/0007).
    struct Project: Equatable, Sendable {
        var name: String
        var link: String = ""
        var details: String = ""
        var tags: [String] = []
    }

    var items: [Item]
    var projects: [Project] = []
    /// The grouping cv-export's skills table renders (decisions/0009).
    var skillCategories: [SkillCategory] = []
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

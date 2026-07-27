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

    /// The Match's matched Tags by primary name, as the confirmed Match
    /// stood when the run started — the overlap view's vocabulary side
    /// ([TAILOR-54], [TAILOR-55]).
    private let matchedTagNames: [String]

    /// Selected projects' relevance stats ([TAILOR-59]) — keyed by the
    /// model object, since the payload id stays behind in the result.
    private let projectRelevance: [ObjectIdentifier: RelevanceStats]

    init(
        result: TailorResult,
        achievementsByID: [String: Achievement],
        projectsByID: [String: Project] = [:],
        matchedTagNames: [String] = []
    ) {
        self.matchedTagNames = matchedTagNames
        // Ids were validated against the payload maps before construction,
        // so every selection resolves.
        items = result.selections.compactMap { selection in
            achievementsByID[selection.achievementID].map {
                ReviewedBullet(
                    achievement: $0, bullet: selection.bullet,
                    relevance: result.relevance[selection.achievementID])
            }
        }
        selectedProjects = result.projects.compactMap { projectsByID[$0] }
        projectRelevance = Dictionary(
            uniqueKeysWithValues: result.projects.compactMap { id in
                projectsByID[id].flatMap { project in
                    result.relevance[id].map { (ObjectIdentifier(project), $0) }
                }
            })
        skillCategories = result.skillCategories
        summary = result.summary
        gaps = result.gaps
        rationale = result.rationale
    }

    /// The judged complement of the overlap view ([TAILOR-62]): a selected
    /// project's relevance stats, verbatim from the result.
    func relevanceStats(for project: Project) -> RelevanceStats? {
        projectRelevance[ObjectIdentifier(project)]
    }

    /// The overlap view's per-point side ([TAILOR-54]): the matched Tags
    /// this point's own Tags cover, by primary name — derived in Swift from
    /// the selection and the Match, never from the model's output.
    func coveredMatchedTags(for achievement: Achievement) -> [String] {
        covered(by: achievement.skills)
    }

    func coveredMatchedTags(for project: Project) -> [String] {
        covered(by: project.skills)
    }

    /// The uncovered remainder ([TAILOR-55]): matched vocabulary the current
    /// selection leaves unevidenced — recomputed, never frozen at result
    /// time.
    var uncoveredMatchedTags: [String] {
        let coveredNames = Set(
            (items.flatMap { coveredMatchedTags(for: $0.achievement) }
                + selectedProjects.flatMap { coveredMatchedTags(for: $0) })
                .map { $0.lowercased() })
        return matchedTagNames.filter { !coveredNames.contains($0.lowercased()) }.sorted()
    }

    private func covered(by skills: [SkillTag]) -> [String] {
        matchedTagNames.filter { name in
            skills.contains { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        }.sorted()
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
    /// The point's judged relevance stats, verbatim from the result
    /// ([TAILOR-59]) — review display only, never persisted.
    let relevance: RelevanceStats?
    var accepted = true

    init(achievement: Achievement, bullet: String, relevance: RelevanceStats? = nil) {
        self.achievement = achievement
        self.bullet = bullet
        self.relevance = relevance
    }
}

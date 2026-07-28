import Foundation

@MainActor
@Observable
final class TailorReview {
    let items: [ReviewedBullet]
    let summary: String
    let gaps: [String]
    let rationale: String

    let selectedProjects: [Project]

    let skillCategories: [SkillCategory]

    private let matchedTagNames: [String]

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

    func relevanceStats(for project: Project) -> RelevanceStats? {
        projectRelevance[ObjectIdentifier(project)]
    }

    func coveredMatchedTags(for achievement: Achievement) -> [String] {
        covered(by: achievement.skills)
    }

    func coveredMatchedTags(for project: Project) -> [String] {
        covered(by: project.skills)
    }

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

struct ReviewedOutcome: Equatable, Sendable {
    struct Item: Equatable, Sendable {
        var canonicalText: String
        var text: String
    }

    struct Project: Equatable, Sendable {
        var name: String
        var link: String = ""
        var details: String = ""
        var tags: [String] = []
    }

    var items: [Item]
    var projects: [Project] = []
    var skillCategories: [SkillCategory] = []
    var summary: String = ""
    var gaps: [String]
    var rationale: String
}

@MainActor
@Observable
final class ReviewedBullet: Identifiable {
    let achievement: Achievement
    let bullet: String
    let relevance: RelevanceStats?
    var accepted = true

    init(achievement: Achievement, bullet: String, relevance: RelevanceStats? = nil) {
        self.achievement = achievement
        self.bullet = bullet
        self.relevance = relevance
    }
}

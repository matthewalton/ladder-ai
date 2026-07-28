import Foundation
import SwiftData

/// Session-scoped: nothing here is persisted, and nothing here writes to the
/// Profile. It dies with the sitting.
struct CVEditSet: Equatable {
    var selectedAchievements: Set<PersistentIdentifier>
    var selectedProjects: Set<PersistentIdentifier>
    var removedRoles: Set<PersistentIdentifier> = []
    var removedEducation: Set<PersistentIdentifier> = []
    var removedInterests: Set<String> = []
    var removedContactLines: Set<String> = []
    var isHeadlineRemoved = false
    var droppedCategories: Set<String> = []
    var droppedSkills: Set<String> = []
    var rewordings: [PersistentIdentifier: String] = [:]
    var summary: String

    @MainActor
    init(review: TailorReview) {
        selectedAchievements = Set(review.items.map(\.achievement.persistentModelID))
        selectedProjects = Set(review.selectedProjects.map(\.persistentModelID))
        summary = review.summary
    }

    // MARK: - Building the document

    @MainActor
    func document(profile: Profile, review: TailorReview) -> CVDocument {
        var document = CVDocument()
        document.name = profile.name
        document.headline = isHeadlineRemoved ? "" : profile.headline
        document.contactLines = [
            profile.contact.email,
            profile.contact.phone,
            profile.contact.location,
            profile.contact.link,
        ].filter { !$0.isEmpty && !removedContactLines.contains($0) }
        document.summary = summary

        var reviewedText: [PersistentIdentifier: String] = [:]
        for item in review.items {
            reviewedText[item.achievement.persistentModelID] =
                item.accepted ? item.bullet : item.achievement.text
        }

        document.roles = orderedRoles(of: profile).map { role in
            CVDocument.RoleSection(
                title: role.title,
                company: role.company,
                start: role.start,
                end: role.end,
                subline: CVDocument.subline(location: role.location, industry: role.industry),
                bullets: selectedAchievements(of: role).map { achievement in
                    let id = achievement.persistentModelID
                    return CVDocument.Bullet(
                        title: achievement.title,
                        text: rewordings[id] ?? reviewedText[id] ?? achievement.text
                    )
                }
            )
        }

        document.projects = selectedProjects(of: profile).map { project in
            CVDocument.ProjectSection(
                name: project.name, link: project.link, details: project.details)
        }

        document.education = profile.orderedEducation
            .filter { !removedEducation.contains($0.persistentModelID) }
            .map { entry in
                CVDocument.EducationSection(
                    institution: entry.institution,
                    qualification: entry.qualification,
                    start: entry.start,
                    end: entry.end,
                    detail: entry.detail
                )
            }

        document.skillCategories = review.skillCategories.compactMap { category in
            guard !droppedCategories.contains(category.name.lowercased()) else { return nil }
            let skills = category.skills.filter { !droppedSkills.contains($0.lowercased()) }
            return skills.isEmpty ? nil : SkillCategory(name: category.name, skills: skills)
        }

        document.interests = profile.interests.filter { !removedInterests.contains($0) }
        return document
    }

    @MainActor
    func orderedRoles(of profile: Profile) -> [Role] {
        profile.roles
            .filter { !removedRoles.contains($0.persistentModelID) }
            .sorted { ($0.start, $1.company) > ($1.start, $0.company) }
    }

    @MainActor
    func selectedAchievements(of role: Role) -> [Achievement] {
        role.orderedAchievements.filter {
            selectedAchievements.contains($0.persistentModelID)
        }
    }

    @MainActor
    func selectedProjects(of profile: Profile) -> [Project] {
        profile.orderedProjects.filter { selectedProjects.contains($0.persistentModelID) }
    }

    // MARK: - Coverage

    /// A point in a removed role is not on the CV, so it carries nothing.
    @MainActor
    func coverage(profile: Profile, matchedTagNames: [String]) -> CVCoverage {
        let tags =
            orderedRoles(of: profile).flatMap { selectedAchievements(of: $0).flatMap(\.skills) }
            + selectedProjects(of: profile).flatMap(\.skills)
        let carried = matchedTagNames.filter { name in
            tags.contains { CVCoverage.resolves($0, to: name) }
        }
        let carriedNames = Set(carried.map { $0.lowercased() })
        return CVCoverage(
            carried: carried.sorted(),
            uncovered: matchedTagNames.filter { !carriedNames.contains($0.lowercased()) }.sorted()
        )
    }
}

struct CVCoverage: Equatable {
    var carried: [String] = []
    var uncovered: [String] = []

    var matchedCount: Int { carried.count + uncovered.count }

    static func resolves(_ tag: SkillTag, to name: String) -> Bool {
        tag.name.caseInsensitiveCompare(name) == .orderedSame
            || tag.aliases.contains(name.lowercased())
    }
}

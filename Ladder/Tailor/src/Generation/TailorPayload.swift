import Foundation

/// `achievementsByID` (`a1…`) and `projectsByID` (`p1…`) are the maps result
/// validation resolves selections against (decisions/0007).
@MainActor
struct TailorPayload {
    let json: String
    let achievementsByID: [String: Achievement]
    let projectsByID: [String: Project]
    /// Tag names per payload id (`a…` and `p…`) — the vocabulary bound the
    /// skill grouping validates against (decisions/0009).
    var tagNamesByID: [String: [String]] {
        var tags: [String: [String]] = [:]
        for (id, achievement) in achievementsByID {
            tags[id] = achievement.skills.map(\.name)
        }
        for (id, project) in projectsByID {
            tags[id] = project.skills.map(\.name)
        }
        return tags
    }

    init(
        profile: Profile, details: JobDetails, matchedTagNames: [String] = [],
        budget: ContentBudget? = nil
    ) throws {
        // Roles newest-first — SwiftData to-many relationships are unordered,
        // and the JSON must be deterministic.
        let orderedRoles = profile.roles.sorted {
            ($0.start, $1.company) > ($1.start, $0.company)
        }
        let matched = Set(matchedTagNames.map { $0.lowercased() })
        var byID: [String: Achievement] = [:]

        // Within each role, achievements rank by descending matched-Tag
        // overlap, ties keeping the Profile's own order ([TAILOR-53]); the
        // roles themselves never reorder — chronology is the CV's spine.
        // Ids are payload-positional, assigned after the ranking, stable
        // within this one payload ([TAILOR-19]).
        var nextRolePointID = 1
        let payloadRoles = orderedRoles.map { role in
            PayloadRole(
                company: role.company,
                title: role.title,
                start: Self.month(from: role.start),
                end: role.end.map(Self.month(from:)),
                achievements: Self.ranked(role.orderedAchievements, by: matched) {
                    Self.overlap(of: $0.skills, with: matched)
                }.map { achievement, overlap in
                    let id = "a\(nextRolePointID)"
                    nextRolePointID += 1
                    byID[id] = achievement
                    return PayloadAchievement(id: id, achievement: achievement, overlap: overlap)
                }
            )
        }

        // Projects serialize as whole units (decisions/0007) — the model
        // includes or omits each by its `p…` id — ranked like achievements.
        var projectsByID: [String: Project] = [:]
        var nextProjectID = 1
        let payloadProjects = Self.ranked(profile.orderedProjects, by: matched) {
            Self.overlap(of: $0.skills, with: matched)
        }.map { project, overlap -> PayloadProject in
            let id = "p\(nextProjectID)"
            nextProjectID += 1
            projectsByID[id] = project
            return PayloadProject(
                id: id,
                name: project.name,
                link: project.link.isEmpty ? nil : project.link,
                summary: project.summary.isEmpty ? nil : project.summary,
                description: project.details.isEmpty ? nil : project.details,
                tags: project.skills.map(\.name).sorted(),
                overlap: overlap
            )
        }

        let payloadEducation = profile.orderedEducation.map { education in
            PayloadEducation(
                institution: education.institution,
                qualification: education.qualification,
                start: Self.month(from: education.start),
                end: education.end.map(Self.month(from:)),
                detail: education.detail.isEmpty ? nil : education.detail
            )
        }

        let body = PayloadBody(
            profile: PayloadProfile(
                name: profile.name,
                headline: profile.headline,
                roles: payloadRoles,
                projects: payloadProjects,
                education: payloadEducation,
                interests: profile.interests
            ),
            job: PayloadJob(
                company: details.company,
                roleTitle: details.roleTitle,
                description: details.jobDescription
            ),
            // Encoded only when history qualifies — an absent budget is no
            // key at all, never zeros ([TAILOR-57], [TAILOR-58]).
            budget: budget.map {
                PayloadBudget(bullets: $0.bullets, projects: $0.projects, characters: $0.characters)
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        json = String(decoding: try encoder.encode(body), as: UTF8.self)
        achievementsByID = byID
        self.projectsByID = projectsByID
    }

    /// Month resolution matches the import prompt's convention.
    private static func month(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    /// The deterministic per-point annotation ([TAILOR-52]): the point's own
    /// Tags intersected with the Match's matched Tags, computed in Swift —
    /// never by the model. Always present; a zero-overlap point carries an
    /// empty list and 0, so absence never reads as "not computed".
    @MainActor
    private static func overlap(of skills: [SkillTag], with matched: Set<String>) -> PayloadOverlap {
        let tags = skills.map(\.name).filter { matched.contains($0.lowercased()) }.sorted()
        return PayloadOverlap(count: tags.count, tags: tags)
    }

    /// Descending overlap count, ties keeping the incoming order — an
    /// explicitly stable sort ([TAILOR-53]).
    private static func ranked<Point>(
        _ points: [Point], by matched: Set<String>, overlap: (Point) -> PayloadOverlap
    ) -> [(Point, PayloadOverlap)] {
        points.enumerated()
            .map { (index: $0.offset, point: $0.element, overlap: overlap($0.element)) }
            .sorted {
                $0.overlap.count != $1.overlap.count
                    ? $0.overlap.count > $1.overlap.count
                    : $0.index < $1.index
            }
            .map { ($0.point, $0.overlap) }
    }
}

/// The [TAILOR-52] annotation: the overlapping primary names, sorted, and
/// their count.
struct PayloadOverlap: Encodable {
    var count: Int
    var tags: [String]
}

private struct PayloadBody: Encodable {
    var profile: PayloadProfile
    var job: PayloadJob
    var budget: PayloadBudget?
}

/// The advisory aim-for line (decisions/0016) — [TAILOR-57].
private struct PayloadBudget: Encodable {
    var bullets: Int
    var projects: Int
    var characters: Int
}

private struct PayloadProfile: Encodable {
    var name: String
    var headline: String
    var roles: [PayloadRole]
    var projects: [PayloadProject]
    var education: [PayloadEducation]
    var interests: [String]
}

private struct PayloadRole: Encodable {
    var company: String
    var title: String
    var start: String
    var end: String?
    var achievements: [PayloadAchievement]
}

private struct PayloadProject: Encodable {
    var id: String
    var name: String
    var link: String?
    var summary: String?
    var description: String?
    var tags: [String]
    var overlap: PayloadOverlap
}

private struct PayloadEducation: Encodable {
    var institution: String
    var qualification: String
    var start: String
    var end: String?
    var detail: String?
}

private struct PayloadAchievement: Encodable {
    var id: String
    var text: String
    var impactMetric: String?
    var tags: [String]
    var strengthNotes: String?
    var overlap: PayloadOverlap

    @MainActor
    init(id: String, achievement: Achievement, overlap: PayloadOverlap) {
        self.id = id
        text = achievement.text
        impactMetric = achievement.impactMetric
        tags = achievement.skills.map(\.name).sorted()
        strengthNotes = achievement.strengthNotes
        self.overlap = overlap
    }
}

private struct PayloadJob: Encodable {
    var company: String
    var roleTitle: String
    var description: String
}

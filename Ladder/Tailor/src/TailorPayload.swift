import Foundation

/// `achievementsByID` is the map result validation resolves selections
/// against — role points (`a1…`) and project points (`p1…`) together.
@MainActor
struct TailorPayload {
    let json: String
    let achievementsByID: [String: Achievement]

    init(profile: Profile, details: JobDetails) throws {
        // Roles newest-first — SwiftData to-many relationships are unordered,
        // and the JSON must be deterministic.
        let orderedRoles = profile.roles.sorted {
            ($0.start, $1.company) > ($1.start, $0.company)
        }
        var byID: [String: Achievement] = [:]

        var nextRolePointID = 1
        let payloadRoles = orderedRoles.map { role in
            PayloadRole(
                company: role.company,
                title: role.title,
                start: Self.month(from: role.start),
                end: role.end.map(Self.month(from:)),
                achievements: role.orderedAchievements.map { achievement in
                    let id = "a\(nextRolePointID)"
                    nextRolePointID += 1
                    byID[id] = achievement
                    return PayloadAchievement(id: id, achievement: achievement)
                }
            )
        }

        var nextProjectPointID = 1
        let payloadProjects = profile.orderedProjects.map { project in
            PayloadProject(
                name: project.name,
                link: project.link.isEmpty ? nil : project.link,
                summary: project.summary.isEmpty ? nil : project.summary,
                points: project.orderedPoints.map { point in
                    let id = "p\(nextProjectPointID)"
                    nextProjectPointID += 1
                    byID[id] = point
                    return PayloadAchievement(id: id, achievement: point)
                }
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
            )
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        json = String(decoding: try encoder.encode(body), as: UTF8.self)
        achievementsByID = byID
    }

    /// Month resolution matches the import prompt's convention.
    private static func month(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }
}

private struct PayloadBody: Encodable {
    var profile: PayloadProfile
    var job: PayloadJob
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
    var name: String
    var link: String?
    var summary: String?
    var points: [PayloadAchievement]
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
    var tech: [String]
    var tags: [String]
    var strengthNotes: String?

    @MainActor
    init(id: String, achievement: Achievement) {
        self.id = id
        text = achievement.text
        impactMetric = achievement.impactMetric
        tech = achievement.tech
        tags = achievement.skills.map(\.name).sorted()
        strengthNotes = achievement.strengthNotes
    }
}

private struct PayloadJob: Encodable {
    var company: String
    var roleTitle: String
    var description: String
}

import Foundation

struct CVDocument: Equatable {
    struct RoleSection: Equatable {
        var title: String
        var company: String
        var start: Date
        var end: Date?  // nil = current role, rendered as "Present"
        var subline: String? = nil
        var bullets: [Bullet]
    }

    struct Bullet: Equatable {
        var title: String? = nil
        var text: String
    }

    struct ProjectSection: Equatable {
        var name: String
        var link: String
        var details: String
    }

    struct EducationSection: Equatable {
        var institution: String
        var qualification: String
        var start: Date
        var end: Date?  // nil = in progress, rendered as "Present"
        var detail: String
    }

    var name: String
    var headline: String
    var contactLines: [String]
    var summary: String = ""
    var roles: [RoleSection]
    var projects: [ProjectSection]
    var education: [EducationSection]
    var skillCategories: [SkillCategory] = []
    var interests: [String] = []

    @MainActor
    init(profile: Profile, review: TailorReview) {
        name = profile.name
        headline = profile.headline
        contactLines = [
            profile.contact.email,
            profile.contact.phone,
            profile.contact.location,
            profile.contact.link,
        ].filter { !$0.isEmpty }
        summary = review.summary

        var reviewedText: [ObjectIdentifier: String] = [:]
        for item in review.items {
            reviewedText[ObjectIdentifier(item.achievement)] =
                item.accepted ? item.bullet : item.achievement.text
        }

        let orderedRoles = profile.roles.sorted {
            ($0.start, $1.company) > ($1.start, $0.company)
        }
        roles = orderedRoles.map { role in
            RoleSection(
                title: role.title,
                company: role.company,
                start: role.start,
                end: role.end,
                subline: Self.subline(location: role.location, industry: role.industry),
                bullets: role.orderedAchievements.compactMap { achievement in
                    reviewedText[ObjectIdentifier(achievement)].map {
                        Bullet(title: achievement.title, text: $0)
                    }
                }
            )
        }

        projects = review.selectedProjects.map { project in
            ProjectSection(name: project.name, link: project.link, details: project.details)
        }

        education = profile.orderedEducation.map { entry in
            EducationSection(
                institution: entry.institution,
                qualification: entry.qualification,
                start: entry.start,
                end: entry.end,
                detail: entry.detail
            )
        }

        skillCategories = review.skillCategories
        interests = profile.interests
    }

    static func subline(location: String?, industry: String?) -> String? {
        let parts = [location, industry].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// UTC and en_US_POSIX so tests are stable.
    static func month(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }

    /// A plain hyphen, deliberately: the bundled Inter subset loses the en
    /// dash in PDF text extraction, and the extracted layer is the
    /// ATS-parseable guarantee.
    static func dateRange(start: Date, end: Date?) -> String {
        "\(month(from: start)) - \(end.map(month(from:)) ?? "Present")"
    }
}

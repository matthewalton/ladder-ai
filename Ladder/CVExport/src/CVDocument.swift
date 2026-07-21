import Foundation

/// The rendered CV's content: full role history, only selected achievements,
/// reviewed text. Built once from the Profile and the review, then handed to
/// the renderer.
struct CVDocument: Equatable {
    struct RoleSection: Equatable {
        var title: String
        var company: String
        var start: Date
        var end: Date?  // nil = current role, rendered as "Present"
        /// Empty for a role with no selected achievements — the role still
        /// appears.
        var bullets: [String]
    }

    struct ProjectSection: Equatable {
        var name: String
        /// "" = no link line.
        var link: String
        var bullets: [String]
    }

    struct EducationSection: Equatable {
        var institution: String
        var qualification: String
        var start: Date
        var end: Date?  // nil = in progress, rendered as "Present"
        /// "" = no detail line.
        var detail: String
    }

    var name: String
    var headline: String
    /// Non-empty contact fields only — no placeholders.
    var contactLines: [String]
    /// Newest-first, the same ordering the tailor payload uses.
    var roles: [RoleSection]
    /// Only projects with at least one selected point — projects are optional
    /// colour, unlike roles, which all appear.
    var projects: [ProjectSection]
    /// Always rendered, newest-first — education is facts, not selectable
    /// content.
    var education: [EducationSection]
    /// Derived per application: the union of Tag names across the selected
    /// points, not the whole profile's Tag vocabulary.
    var skills: [String]

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

        // Reviewed text per selected achievement: the accepted expanded
        // bullet, or the canonical brief point where it was rejected. Keyed by
        // object identity, which survives to the role grouping below.
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
                bullets: role.orderedAchievements.compactMap {
                    reviewedText[ObjectIdentifier($0)]
                }
            )
        }

        projects = profile.orderedProjects.compactMap { project in
            let bullets = project.orderedPoints.compactMap {
                reviewedText[ObjectIdentifier($0)]
            }
            guard !bullets.isEmpty else { return nil }
            return ProjectSection(name: project.name, link: project.link, bullets: bullets)
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

        skills = Array(
            Set(review.items.flatMap { $0.achievement.skills.map(\.name) })
        ).sorted()
    }

    /// Month resolution, matching the tailor payload; UTC so tests are
    /// stable.
    static func month(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }

    static func dateRange(start: Date, end: Date?) -> String {
        "\(month(from: start)) – \(end.map(month(from:)) ?? "Present")"
    }
}

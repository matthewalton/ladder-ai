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
        /// The grey meta subline (Profile decisions/0010, [CVEXPORT-31]):
        /// "location · industry", either alone, or nil for no subline.
        var subline: String? = nil
        /// Empty for a role with no selected achievements — the role still
        /// appears.
        var bullets: [Bullet]
    }

    /// One rendered CV bullet: the canonical `Achievement.title` as the
    /// bold lead phrase — tailoring never writes it — and the reviewed
    /// text ([CVEXPORT-32]). A nil title renders the text alone.
    struct Bullet: Equatable {
        var title: String? = nil
        var text: String
    }

    struct ProjectSection: Equatable {
        var name: String
        /// "" = no link line.
        var link: String
        /// The project's description, one prose block — verbatim from the
        /// Profile (Tailor decisions/0007). "" renders no body.
        var details: String
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
    /// The generated CV summary (Tailor decisions/0006) — "" renders no
    /// summary block.
    var summary: String = ""
    /// Newest-first, the same ordering the tailor payload uses.
    var roles: [RoleSection]
    /// Only selected projects (decisions/0005) — projects are optional
    /// colour, unlike roles, which all appear.
    var projects: [ProjectSection]
    /// Always rendered, newest-first — education is facts, not selectable
    /// content.
    var education: [EducationSection]
    /// The per-CV skill grouping, verbatim from the reviewed outcome
    /// ([TAILOR-24], [CVEXPORT-23]) — replaces the retired flat skills
    /// line. Validation already bounded every skill to the selection's Tag
    /// union (Tailor decisions/0009), so the decisions/0004 vocabulary rule
    /// holds here by construction.
    var skillCategories: [SkillCategory] = []
    /// The Profile's interests, entry order ([PROFILE-14]) — rendered as
    /// the closing section, or no section when empty ([CVEXPORT-33]).
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

    /// "location · industry" — either alone when the other is nil, nil when
    /// both are ([CVEXPORT-31]; the fields are nil-or-present by Profile
    /// decisions/0010, never empty strings).
    static func subline(location: String?, industry: String?) -> String? {
        let parts = [location, industry].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
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

    /// A plain hyphen, deliberately: the bundled Inter subset loses the en
    /// dash in PDF text extraction, and the extracted layer is the
    /// ATS-parseable guarantee.
    static func dateRange(start: Date, end: Date?) -> String {
        "\(month(from: start)) - \(end.map(month(from:)) ?? "Present")"
    }
}

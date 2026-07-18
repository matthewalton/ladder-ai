import Foundation

/// The rendered CV's content (slice CONTEXT.md, decisions/0002): full role
/// history, only selected achievements, reviewed text. A plain value — built
/// once from the Profile and the review, then handed to the renderer.
struct CVDocument: Equatable {
    struct RoleSection: Equatable {
        var title: String
        var company: String
        var start: Date
        var end: Date?  // nil = current role, rendered as "Present"
        /// The selected achievements under this role, in their persisted
        /// order, each in reviewed text ([CVEXPORT-4]). Empty for a role
        /// with no selected achievements — the role still appears
        /// ([CVEXPORT-3]).
        var bullets: [String]
    }

    var name: String
    var headline: String
    /// Non-empty contact fields only — empty ones are omitted, no
    /// placeholders ([CVEXPORT-2]).
    var contactLines: [String]
    /// Newest-first, the same ordering the tailor payload uses.
    var roles: [RoleSection]
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

        // The reviewed text per selected achievement: the accepted
        // rephrasing, or the canonical text where the rephrasing was
        // rejected ([TAILOR-13], [TAILOR-14]). The review holds the
        // Achievement models, so identity survives to the role grouping.
        var reviewedText: [ObjectIdentifier: String] = [:]
        for item in review.items {
            reviewedText[ObjectIdentifier(item.achievement)] =
                item.accepted ? item.rephrasing : item.achievement.text
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

        skills = profile.skills.map(\.name).sorted()
    }

    /// Month-resolution dates ([CVEXPORT-3] body), matching the tailor
    /// payload's resolution; UTC like the payload so tests are stable.
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

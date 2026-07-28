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

    var name: String = ""
    var headline: String = ""
    var contactLines: [String] = []
    var summary: String = ""
    var roles: [RoleSection] = []
    var projects: [ProjectSection] = []
    var education: [EducationSection] = []
    var skillCategories: [SkillCategory] = []
    var interests: [String] = []

    init() {}

    @MainActor
    init(profile: Profile, review: TailorReview) {
        self = CVEditSet(review: review).document(profile: profile, review: review)
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

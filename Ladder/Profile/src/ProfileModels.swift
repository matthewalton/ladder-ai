import Foundation
import SwiftData

// Roadmap-minimal schema (decisions/0003): Profile, Role, Achievement,
// SkillTag, ContactInfo. Education/Project arrive with the slice that needs
// them. ARCHITECTURE.md §3 is the target shape.

/// The Profile's identity-header value type (slice CONTEXT.md: contact info).
struct ContactInfo: Codable, Hashable {
    var email: String = ""
    var phone: String = ""
    var location: String = ""
    var link: String = ""
}

@Model
final class Profile {
    var name: String
    var headline: String
    var contact: ContactInfo
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Role.profile)
    var roles: [Role]

    @Relationship(deleteRule: .cascade, inverse: \SkillTag.profile)
    var skills: [SkillTag]

    init(name: String, headline: String, contact: ContactInfo = ContactInfo(), updatedAt: Date = .now) {
        self.name = name
        self.headline = headline
        self.contact = contact
        self.updatedAt = updatedAt
        self.roles = []
        self.skills = []
    }
}

@Model
final class Role {
    var company: String
    var title: String
    var start: Date
    var end: Date?  // nil = current role
    var profile: Profile?

    @Relationship(deleteRule: .cascade, inverse: \Achievement.role)
    var achievements: [Achievement]

    init(company: String, title: String, start: Date, end: Date? = nil) {
        self.company = company
        self.title = title
        self.start = start
        self.end = end
        self.achievements = []
    }

    /// Achievements in their persisted drag order. SwiftData to-many
    /// relationships are unordered; `sortIndex` carries the order
    /// (SPEC.md [PROFILE-7] body).
    var orderedAchievements: [Achievement] {
        achievements.sorted { $0.sortIndex < $1.sortIndex }
    }
}

@Model
final class Achievement {
    var text: String  // canonical, user-owned wording — never edited by the LLM
    var impactMetric: String?
    var tech: [String]
    var strengthNotes: String?
    var sortIndex: Int
    var role: Role?

    @Relationship
    var skills: [SkillTag]

    init(
        text: String,
        impactMetric: String? = nil,
        tech: [String] = [],
        strengthNotes: String? = nil,
        sortIndex: Int = 0
    ) {
        self.text = text
        self.impactMetric = impactMetric
        self.tech = tech
        self.strengthNotes = strengthNotes
        self.sortIndex = sortIndex
        self.skills = []
    }
}

/// One named skill shared across the Profile — achievements reference
/// SkillTags, they never own private copies (slice CONTEXT.md).
@Model
final class SkillTag {
    var name: String
    var profile: Profile?

    @Relationship(inverse: \Achievement.skills)
    var achievements: [Achievement]

    init(name: String) {
        self.name = name
        self.achievements = []
    }
}

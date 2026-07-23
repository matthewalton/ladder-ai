import Foundation
import SwiftData

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

    @Relationship(deleteRule: .cascade, inverse: \Education.profile)
    var education: [Education] = []

    @Relationship(deleteRule: .cascade, inverse: \Project.profile)
    var projects: [Project] = []

    /// Ordered; arrays persist order so no model is needed.
    var interests: [String] = []

    init(name: String, headline: String, contact: ContactInfo = ContactInfo(), updatedAt: Date = .now) {
        self.name = name
        self.headline = headline
        self.contact = contact
        self.updatedAt = updatedAt
        self.roles = []
        self.skills = []
        self.education = []
        self.projects = []
        self.interests = []
    }

    /// Newest-first, matching the role ordering convention.
    var orderedEducation: [Education] {
        education.sorted { ($0.start, $1.institution) > ($1.start, $0.institution) }
    }

    var orderedProjects: [Project] {
        projects.sorted { $0.sortIndex < $1.sortIndex }
    }
}

@Model
final class Role {
    var company: String
    var title: String
    var start: Date
    var end: Date?  // nil = current role
    /// Print fields for the CV template's subline (decisions/0010).
    /// nil = absent — never an empty string; backfilled manually.
    var location: String?
    var industry: String?
    var profile: Profile?

    @Relationship(deleteRule: .cascade, inverse: \Achievement.role)
    var achievements: [Achievement]

    init(
        company: String, title: String, start: Date, end: Date? = nil,
        location: String? = nil, industry: String? = nil
    ) {
        self.company = company
        self.title = title
        self.start = start
        self.end = end
        self.location = location
        self.industry = industry
        self.achievements = []
    }

    /// SwiftData to-many relationships are unordered; `sortIndex` carries
    /// the drag order.
    var orderedAchievements: [Achievement] {
        achievements.sorted { $0.sortIndex < $1.sortIndex }
    }
}

@Model
final class Education {
    var institution: String
    var qualification: String
    var start: Date
    var end: Date?  // nil = in progress
    var detail: String  // "" = none
    var profile: Profile?

    init(institution: String, qualification: String, start: Date, end: Date? = nil, detail: String = "") {
        self.institution = institution
        self.qualification = qualification
        self.start = start
        self.end = end
        self.detail = detail
    }
}

@Model
final class Project {
    var name: String
    var link: String  // "" = none
    var summary: String  // "" = none, the one-line shown beside the name
    /// "" = none, the multi-line description (decisions/0009). The stored
    /// default lets an existing store migrate in place.
    var details: String = ""
    var sortIndex: Int
    var profile: Profile?

    @Relationship
    var skills: [SkillTag]

    init(name: String, link: String = "", summary: String = "", details: String = "", sortIndex: Int = 0) {
        self.name = name
        self.link = link
        self.summary = summary
        self.details = details
        self.sortIndex = sortIndex
        self.skills = []
    }
}

@Model
final class Achievement {
    /// The optional bold lead phrase on a rendered CV bullet (root
    /// CONTEXT.md; decisions/0010). Canon like the text: manual backfill,
    /// never written by tailoring. nil = titleless — renders plain.
    var title: String?
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
        title: String? = nil,
        impactMetric: String? = nil,
        tech: [String] = [],
        strengthNotes: String? = nil,
        sortIndex: Int = 0
    ) {
        self.title = title
        self.text = text
        self.impactMetric = impactMetric
        self.tech = tech
        self.strengthNotes = strengthNotes
        self.sortIndex = sortIndex
        self.skills = []
    }
}

/// Shared across the Profile — achievements and projects reference SkillTags,
/// they never own private copies.
@Model
final class SkillTag {
    var name: String
    var profile: Profile?

    @Relationship(inverse: \Achievement.skills)
    var achievements: [Achievement]

    @Relationship(inverse: \Project.skills)
    var projects: [Project]

    init(name: String) {
        self.name = name
        self.achievements = []
        self.projects = []
    }
}

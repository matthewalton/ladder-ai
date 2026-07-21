import Foundation

/// Everything the replace pathway writes (decisions/0008), as plain values —
/// built by callers (CV import's merge) from reviewed content, never from
/// live models.
struct ProfileReplacement: Equatable, Sendable {
    var name: String
    var headline: String
    var contact: ContactInfo
    var roles: [ReplacementRole] = []
    var education: [ReplacementEducation] = []
    var projects: [ReplacementProject] = []
    var interests: [String] = []
}

struct ReplacementRole: Equatable, Sendable {
    var company: String
    var title: String
    var start: Date
    var end: Date?  // nil = current role
    var achievements: [ReplacementPoint] = []
}

/// One brief point — a role achievement or a project point; skills are Tag
/// names, resolved against the rebuilt pool by the [PROFILE-8] rule.
struct ReplacementPoint: Equatable, Sendable {
    var text: String
    var impactMetric: String? = nil
    var tech: [String] = []
    var skills: [String] = []
}

struct ReplacementEducation: Equatable, Sendable {
    var institution: String
    var qualification: String
    var start: Date
    var end: Date?  // nil = in progress
    var detail: String = ""
}

struct ReplacementProject: Equatable, Sendable {
    var name: String
    var link: String = ""
    var summary: String = ""
    var points: [ReplacementPoint] = []
}

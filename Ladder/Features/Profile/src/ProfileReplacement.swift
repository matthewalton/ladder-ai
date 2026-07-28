import Foundation

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
    var end: Date?
    var location: String? = nil
    var industry: String? = nil
    var achievements: [ReplacementPoint] = []
}

struct ReplacementPoint: Equatable, Sendable {
    var title: String? = nil
    var text: String
    var impactMetric: String? = nil
    var skills: [String] = []
}

struct ReplacementEducation: Equatable, Sendable {
    var institution: String
    var qualification: String
    var start: Date
    var end: Date?
    var detail: String = ""
}

struct ReplacementProject: Equatable, Sendable {
    var name: String
    var link: String = ""
    var summary: String = ""
    var details: String = ""
    var skills: [String] = []
}

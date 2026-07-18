import Foundation

/// What the tailor sheet collects (slice CONTEXT.md). Transient — nothing
/// here is persisted in this slice (decisions/0001); the Application model
/// arrives with cv-export.
struct JobDetails: Equatable, Sendable {
    var company: String
    var roleTitle: String
    var jobDescription: String
}

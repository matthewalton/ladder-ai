import Foundation

struct JobDetails: Equatable, Sendable {
    var company: String
    var roleTitle: String
    var jobDescription: String
}

extension JobDetails {
    /// The run's details derive from the Application, verbatim
    /// ([TAILOR-23], decisions/0008) — the tailor collects nothing by hand.
    @MainActor
    init(application: Application) {
        self.init(
            company: application.company,
            roleTitle: application.roleTitle,
            jobDescription: application.jobDescription
        )
    }
}

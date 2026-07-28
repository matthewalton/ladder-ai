import Foundation

struct JobDetails: Equatable, Sendable {
    var company: String
    var roleTitle: String
    var jobDescription: String
}

extension JobDetails {
    @MainActor
    init(application: Application) {
        self.init(
            company: application.company,
            roleTitle: application.roleTitle,
            jobDescription: application.jobDescription
        )
    }
}

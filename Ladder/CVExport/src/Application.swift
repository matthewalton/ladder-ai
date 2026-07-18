import Foundation
import SwiftData

/// The full ARCHITECTURE.md §3 case set — the enum is the cheap part — but
/// export only ever writes `.applied` (SPEC.md [CVEXPORT-10], decisions/0001).
/// The other cases wait for the Phase 2 pipeline board.
enum ApplicationStatus: String, Codable, CaseIterable, Sendable {
    case draft
    case applied
    case active
    case offer
    case rejected
    case withdrawn
}

/// One pursuit of a specific job at a company (root CONTEXT.md), roadmap-
/// minimal (decisions/0001): no Stage chain until Phase 2. `cvSnapshot` is
/// written once at export and never mutated — the historical record of what
/// was actually sent must be exact.
@Model
final class Application {
    var company: String
    var roleTitle: String
    var jobDescription: String
    var status: ApplicationStatus
    var cvSnapshot: Data?
    var cvSelectionRationale: String?
    var createdAt: Date

    init(
        company: String,
        roleTitle: String,
        jobDescription: String,
        status: ApplicationStatus,
        cvSnapshot: Data? = nil,
        cvSelectionRationale: String? = nil,
        createdAt: Date = .now
    ) {
        self.company = company
        self.roleTitle = roleTitle
        self.jobDescription = jobDescription
        self.status = status
        self.cvSnapshot = cvSnapshot
        self.cvSelectionRationale = cvSelectionRationale
        self.createdAt = createdAt
    }
}

import Foundation
import SwiftData

enum ApplicationStatus: String, Codable, CaseIterable, Sendable {
    case draft
    case applied
    case active
    case offer
    case rejected
    case withdrawn
}

/// One pursuit of a specific job at a company. `cvSnapshot` is written once
/// at export and never mutated — the record of what was actually sent must be
/// exact. `notes` keeps its default at the declaration: lightweight migration
/// fills existing rows from there, not from `init`.
@Model
final class Application {
    var company: String
    var roleTitle: String
    var jobDescription: String
    var source: String?
    var status: ApplicationStatus
    var appliedAt: Date?
    var cvSnapshot: Data?
    var cvSelectionRationale: String?
    /// What the fit loop saw and did for this export ([CVEXPORT-30],
    /// decisions/0008); written once beside the snapshot. The declaration
    /// default migrates existing rows to nil.
    var fitMetrics: FitMetrics? = nil
    var createdAt: Date
    var notes: String = ""

    @Relationship(deleteRule: .cascade, inverse: \Stage.application)
    var stages: [Stage]

    /// One journey narrative per Application; deleting the Application
    /// deletes it too (owned by the journey-synthesis slice — see
    /// Ladder/JourneySynthesis/).
    @Relationship(deleteRule: .cascade, inverse: \JourneyNarrative.application)
    var journeyNarrative: JourneyNarrative?

    /// To-many relationships are unordered; `sortIndex` carries the chain
    /// order.
    var orderedStages: [Stage] {
        stages.sorted { $0.sortIndex < $1.sortIndex }
    }

    init(
        company: String,
        roleTitle: String,
        jobDescription: String,
        status: ApplicationStatus,
        source: String? = nil,
        appliedAt: Date? = nil,
        cvSnapshot: Data? = nil,
        cvSelectionRationale: String? = nil,
        createdAt: Date = .now,
        notes: String = ""
    ) {
        self.company = company
        self.roleTitle = roleTitle
        self.jobDescription = jobDescription
        self.source = source
        self.status = status
        self.appliedAt = appliedAt
        self.cvSnapshot = cvSnapshot
        self.cvSelectionRationale = cvSelectionRationale
        self.createdAt = createdAt
        self.notes = notes
        self.stages = []
    }
}

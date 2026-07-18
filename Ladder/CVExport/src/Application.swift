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

/// One pursuit of a specific job at a company (root CONTEXT.md). Phase 2
/// grew the model in place — Stage chain, applied date, source, notes
/// (PipelineBoard decisions/0001; CVExport decisions/0001 handed that off).
/// `cvSnapshot` is written once at export and never mutated — the historical
/// record of what was actually sent must be exact. `notes` keeps its default
/// at the declaration: lightweight migration fills existing rows from there,
/// not from `init` ([PIPEBOARD-2]).
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
    var createdAt: Date
    var notes: String = ""

    @Relationship(deleteRule: .cascade, inverse: \Stage.application)
    var stages: [Stage]

    /// Stages in chain order. To-many relationships are unordered;
    /// `sortIndex` carries the order ([PIPEBOARD-10], the [PROFILE-7]
    /// pattern).
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

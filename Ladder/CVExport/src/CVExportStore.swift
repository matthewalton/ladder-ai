import Foundation
import SwiftData

/// One render serves both destinations — snapshot and save panel.
@MainActor
@Observable
final class CVExportStore {
    /// `pdfData` is the same bytes as `application.cvSnapshot` — one render,
    /// never a second.
    struct Export {
        let application: Application
        let pdfData: Data
        let fitReport: FitReport
    }

    private let context: ModelContext

    init(container: ModelContainer) {
        context = ModelContext(container)
    }

    /// The Profile is read, never written; each call creates a fresh
    /// Application.
    @discardableResult
    func export(profile: Profile, review: TailorReview, details: JobDetails) throws -> Export {
        let document = CVDocument(profile: profile, review: review)
        let pdfData = CVRenderer.pdfData(for: document)
        let outcome = review.outcome
        let application = Application(
            company: details.company,
            roleTitle: details.roleTitle,
            jobDescription: details.jobDescription,
            status: .applied,
            cvSnapshot: pdfData,
            cvSelectionRationale: outcome.rationale
        )
        context.insert(application)
        try context.save()
        return Export(
            application: application,
            pdfData: pdfData,
            fitReport: FitReport(outcome: outcome)
        )
    }
}

/// Strengths derived from the selection step, gaps and rationale verbatim
/// from the reviewed outcome — nothing re-derived from the JD.
struct FitReport: Equatable {
    /// One strength per selected achievement, in reviewed text.
    var strengths: [String]
    var gaps: [String]
    var rationale: String

    init(outcome: ReviewedOutcome) {
        strengths = outcome.items.map(\.text)
        gaps = outcome.gaps
        rationale = outcome.rationale
    }
}

import Foundation
import SwiftData

/// MVVM-lite store for the export (slice CONTEXT.md): render the CV, persist
/// the Application, and hand back the one render for both destinations —
/// snapshot and save panel (decisions/0003).
@MainActor
@Observable
final class CVExportStore {
    /// One export's outputs. `pdfData` is the same bytes as
    /// `application.cvSnapshot` — one render, never a second ([CVEXPORT-12]).
    struct Export {
        let application: Application
        let pdfData: Data
        let fitReport: FitReport
    }

    private let context: ModelContext

    init(container: ModelContainer) {
        context = ModelContext(container)
    }

    /// The export ([CVEXPORT-1]): reviewed outcome + job details + Profile →
    /// rendered PDF → persisted Application. The Profile is read, never
    /// written ([CVEXPORT-14]); each call creates a fresh Application
    /// ([CVEXPORT-13]).
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

/// The fit report's content (slice CONTEXT.md): strengths derived from the
/// selection step, gaps and rationale verbatim from the reviewed outcome —
/// nothing re-derived from the JD ([CVEXPORT-15]–[CVEXPORT-17]).
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

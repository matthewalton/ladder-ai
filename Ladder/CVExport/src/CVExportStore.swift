import Foundation
import SwiftData

enum CVExportError: Error, Equatable {
    case applicationMissing
    /// A fit pass failed after its single repair (Tailor decisions/0010) —
    /// the reason travels so the export surfaces it, never a silent
    /// fallback.
    case fitFailed(String)
}

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

    /// The Profile is read, never written; export attaches to the
    /// application the tailor ran for (decisions/0006) — never a fresh row.
    /// By ID, fetched in this store's own context: mutating an instance from
    /// another context would not save here. The fit loop (decisions/0008)
    /// runs before the render — `fitPasses` is only called when compaction
    /// alone cannot land two pages ([CVEXPORT-26/27]).
    @discardableResult
    func export(
        profile: Profile,
        review: TailorReview,
        into applicationID: PersistentIdentifier,
        fitPasses: FitPassRunner? = nil
    ) async throws -> Export {
        var descriptor = FetchDescriptor<Application>(
            predicate: #Predicate { $0.persistentModelID == applicationID })
        descriptor.fetchLimit = 1
        guard let application = try context.fetch(descriptor).first else {
            throw CVExportError.applicationMissing
        }
        let document = CVDocument(profile: profile, review: review)
        let fitOutcome: CVFitLoop.Outcome
        do {
            fitOutcome = try await CVFitLoop(fitPasses: fitPasses)
                .fit(document: document, jobDescription: application.jobDescription)
        } catch let failure as TailorValidationFailure {
            throw CVExportError.fitFailed(failure.reason)
        }
        let pdfData = CVRenderer.pdfData(for: fitOutcome.document, metrics: fitOutcome.metrics)
        let outcome = review.outcome
        application.cvSnapshot = pdfData
        application.cvSelectionRationale = outcome.rationale
        application.fitMetrics = fitOutcome.fitMetrics
        // Exporting is the act of applying ([CVEXPORT-10]); an existing
        // status past draft — and an existing date — are never touched.
        if application.status == .draft {
            application.status = .applied
            if application.appliedAt == nil {
                application.appliedAt = .now
            }
        }
        try context.save()
        return Export(
            application: application,
            pdfData: pdfData,
            fitReport: FitReport(outcome: outcome, trimmed: fitOutcome.trimmedItems)
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
    /// Items the fit loop trimmed to land two pages ([CVEXPORT-28]) —
    /// nothing is silently dropped. Empty when nothing was.
    var trimmed: [String]

    init(outcome: ReviewedOutcome, trimmed: [String] = []) {
        strengths = outcome.items.map(\.text)
        gaps = outcome.gaps
        rationale = outcome.rationale
        self.trimmed = trimmed
    }
}

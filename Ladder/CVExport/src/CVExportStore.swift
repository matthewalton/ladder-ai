import Foundation
import SwiftData

enum CVExportError: Error, Equatable {
    case applicationMissing
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
    /// another context would not save here.
    @discardableResult
    func export(
        profile: Profile, review: TailorReview, into applicationID: PersistentIdentifier
    ) throws -> Export {
        var descriptor = FetchDescriptor<Application>(
            predicate: #Predicate { $0.persistentModelID == applicationID })
        descriptor.fetchLimit = 1
        guard let application = try context.fetch(descriptor).first else {
            throw CVExportError.applicationMissing
        }
        let document = CVDocument(profile: profile, review: review)
        let pdfData = CVRenderer.pdfData(for: document)
        let outcome = review.outcome
        application.cvSnapshot = pdfData
        application.cvSelectionRationale = outcome.rationale
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

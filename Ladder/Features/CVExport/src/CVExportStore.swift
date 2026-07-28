import Foundation
import SwiftData

enum CVExportError: Error, Equatable {
    case applicationMissing
    case fitFailed(String)
}

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

    /// By ID, fetched in this store's own context: mutating an instance from
    /// another context would not save here.
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

struct FitReport: Equatable {
    var strengths: [String]
    var gaps: [String]
    var rationale: String
    var trimmed: [String]

    init(outcome: ReviewedOutcome, trimmed: [String] = []) {
        strengths = outcome.items.map(\.text)
        gaps = outcome.gaps
        rationale = outcome.rationale
        self.trimmed = trimmed
    }
}

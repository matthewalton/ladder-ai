import Foundation
import SwiftData

enum CVExportError: Error, Equatable {
    case applicationMissing
    case fitFailed(String)
    case overTwoPages(Int)
}

/// Building one of these touches no persisted state, so a composition the
/// user abandons leaves nothing behind.
struct CVComposition {
    var fit: CVFitLoop.Outcome
    var pdfData: Data
    var fitReport: FitReport
    var rationale: String

    var document: CVDocument { fit.document }
    var pageCount: Int { fit.pageCount }
    var fitMetrics: FitMetrics { fit.fitMetrics }
    var fitsTwoPages: Bool { fit.pageCount <= CVFitLoop.pageCap }

    @MainActor
    init(fit: CVFitLoop.Outcome, outcome: ReviewedOutcome) {
        self.fit = fit
        pdfData = CVRenderer.pdfData(for: fit.document, metrics: fit.metrics)
        fitReport = FitReport(
            outcome: outcome, document: fit.document, trimmed: fit.trimmedItems)
        rationale = outcome.rationale
    }
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

    func compose(
        profile: Profile,
        review: TailorReview,
        for applicationID: PersistentIdentifier,
        edits: CVEditSet? = nil,
        fitPasses: FitPassRunner? = nil
    ) async throws -> CVComposition {
        let application = try fetch(applicationID)
        let document = (edits ?? CVEditSet(review: review))
            .document(profile: profile, review: review)
        let fitOutcome: CVFitLoop.Outcome
        do {
            fitOutcome = try await CVFitLoop(fitPasses: fitPasses)
                .fit(document: document, jobDescription: application.jobDescription)
        } catch let failure as TailorValidationFailure {
            throw CVExportError.fitFailed(failure.reason)
        }
        return CVComposition(fit: fitOutcome, outcome: review.outcome)
    }

    @discardableResult
    func export(
        _ composition: CVComposition, into applicationID: PersistentIdentifier
    ) throws -> Export {
        guard composition.fitsTwoPages else {
            throw CVExportError.overTwoPages(composition.pageCount)
        }
        let application = try fetch(applicationID)
        application.cvSnapshot = composition.pdfData
        application.cvSelectionRationale = composition.rationale
        application.fitMetrics = composition.fitMetrics
        if application.status == .draft {
            application.status = .applied
            if application.appliedAt == nil {
                application.appliedAt = .now
            }
        }
        try context.save()
        return Export(
            application: application,
            pdfData: composition.pdfData,
            fitReport: composition.fitReport
        )
    }

    @discardableResult
    func export(
        profile: Profile,
        review: TailorReview,
        into applicationID: PersistentIdentifier,
        fitPasses: FitPassRunner? = nil
    ) async throws -> Export {
        let composition = try await compose(
            profile: profile, review: review, for: applicationID, fitPasses: fitPasses)
        return try export(composition, into: applicationID)
    }

    /// By ID, fetched in this store's own context: mutating an instance from
    /// another context would not save here.
    private func fetch(_ applicationID: PersistentIdentifier) throws -> Application {
        var descriptor = FetchDescriptor<Application>(
            predicate: #Predicate { $0.persistentModelID == applicationID })
        descriptor.fetchLimit = 1
        guard let application = try context.fetch(descriptor).first else {
            throw CVExportError.applicationMissing
        }
        return application
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

    /// Strengths follow the selection as it currently stands, so a point the
    /// user added in the preview is a strength like any other.
    init(outcome: ReviewedOutcome, document: CVDocument, trimmed: [String] = []) {
        self.init(outcome: outcome, trimmed: trimmed)
        strengths = document.roles.flatMap { $0.bullets.map(\.text) }
    }
}

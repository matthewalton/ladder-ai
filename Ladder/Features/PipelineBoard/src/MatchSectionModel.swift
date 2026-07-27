import Foundation
import SwiftData

/// The application detail's Match section flow (decisions/0009): the
/// on-demand door into the JD scan and Match review. Scan → review →
/// confirm or cancel, ending back at the detail — never a tailor run
/// ([PIPEBOARD-47]). The scan machinery and the review's semantics are
/// Tailor's ([TAILOR-27]–[TAILOR-42], [TAILOR-46]–[TAILOR-51]); this model
/// only drives them from the detail.
@MainActor
@Observable
final class MatchSectionModel {
    enum Phase: Equatable {
        case idle
        case scanning
        /// `matchReview` is non-nil; the flow holds here until the review
        /// confirms or cancels.
        case review
        case failed(JDScanError)
    }

    /// What the section renders ([PIPEBOARD-43]): a read of the persisted
    /// Match, nothing more. nil is the prompt state ([PIPEBOARD-46]).
    struct Summary: Equatable {
        var score: Int?
        var matchedTagNames: [String]
        var vocabularyGaps: [String]
        var scannedAt: Date
    }

    private(set) var phase: Phase = .idle
    private(set) var matchReview: MatchReviewModel?
    /// Per-suggestion refusals from the last confirm — surfaced, never
    /// silent ([TAILOR-48]'s stance).
    private(set) var confirmationNotes: [String] = []

    private let scanStore: JDScanStore
    private let application: Application

    init(
        application: Application,
        keyStore: any APIKeyStore,
        bundle: Bundle = .main,
        makeIntelligence: @escaping (String) -> any IntelligenceService = {
            AnthropicIntelligenceService(apiKey: $0)
        }
    ) {
        self.application = application
        scanStore = JDScanStore(
            keyStore: keyStore, bundle: bundle, makeIntelligence: makeIntelligence)
    }

    /// The gate is the JD alone ([PIPEBOARD-45]) — any status, snapshot or
    /// not; deliberately unlike Create CV's gate ([PIPEBOARD-42]).
    static func offersMatchSection(jobDescription: String) -> Bool {
        !jobDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// nil when the Application has no Match — the prompt state. Reading
    /// the persisted Match directly means a re-scan's replacement
    /// ([TAILOR-36]) and a confirmed review's gap-moves ([TAILOR-49]) show
    /// without any refresh step.
    static func summary(of application: Application) -> Summary? {
        guard let match = application.match else { return nil }
        return Summary(
            score: match.score,
            matchedTagNames: match.matchedTags.map(\.name),
            vocabularyGaps: match.vocabularyGaps,
            scannedAt: match.scannedAt)
    }

    var summary: Summary? { Self.summary(of: application) }

    /// The door ([PIPEBOARD-44]): run the JD scan — a repeat scan replaces
    /// the Match ([TAILOR-36]) — and hold in the Match review on success.
    func scan() async {
        phase = .scanning
        matchReview = nil
        confirmationNotes = []
        await scanStore.scan(application)
        switch scanStore.phase {
        case .scanned:
            guard let match = application.match else {
                phase = .failed(.requestFailed(detail: "the scan stored no Match"))
                return
            }
            matchReview = MatchReviewModel(match: match, suggestions: scanStore.suggestions)
            phase = .review
        case .failed(let error):
            phase = .failed(error)
        case .idle, .scanning:
            phase = .failed(.requestFailed(detail: "the scan never completed"))
        }
    }

    /// Confirm applies the review through the shared seam — pool writes
    /// and gap-moves per [TAILOR-48]/[TAILOR-49] — and ends back at the
    /// detail: no tailor run follows ([PIPEBOARD-47]; decisions/0009).
    func confirmReview() {
        guard phase == .review, let matchReview else { return }
        do {
            confirmationNotes = try MatchReviewConfirmation.apply(
                matchReview, to: application)
            self.matchReview = nil
            phase = .idle
        } catch {
            self.matchReview = nil
            phase = .failed(.requestFailed(detail: "saving the confirmed review failed"))
        }
    }

    /// Dismissal writes nothing — pool and Match stay exactly as the scan
    /// left them ([TAILOR-50]).
    func cancelReview() {
        matchReview = nil
        phase = .idle
    }

    func retry() async {
        await scan()
    }
}

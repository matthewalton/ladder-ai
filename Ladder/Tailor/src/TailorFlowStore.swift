import Foundation
import SwiftData

/// The scan-first tailor flow (root ADR 0005: the Match review precedes
/// selection): presenting the tailor scans, the Match review confirms the
/// vocabulary, and only then does the tailor run start — grounded in the
/// confirmed Match, never a raw JD. A failed scan fails the whole flow;
/// retry re-runs from the scan (decisions/0014).
@MainActor
@Observable
final class TailorFlowStore {
    enum Phase: Equatable {
        case scanning
        /// `matchReview` is non-nil; the flow holds here until the review
        /// confirms or the view dismisses ([TAILOR-45]).
        case matchReview
        /// The tailor run — the repair request runs here too.
        case tailoring
        /// `review` is non-nil.
        case review
        case scanFailed(JDScanError)
        case tailorFailed(TailorError)
    }

    private(set) var phase: Phase = .scanning
    private(set) var matchReview: MatchReviewModel?
    /// Per-suggestion refusals surfaced at confirmation — a colliding alias
    /// is skipped, never a reason to derail the rest ([TAILOR-48]).
    private(set) var confirmationNotes: [String] = []

    let scanStore: JDScanStore
    let tailorStore: TailorStore

    private let profileStore: ProfileStore
    private let application: Application
    private let details: JobDetails

    var review: TailorReview? { tailorStore.review }

    init(
        profileStore: ProfileStore,
        application: Application,
        keyStore: any APIKeyStore,
        bundle: Bundle = .main,
        makeIntelligence: @escaping (String) -> any IntelligenceService = {
            AnthropicIntelligenceService(apiKey: $0)
        }
    ) {
        self.profileStore = profileStore
        self.application = application
        details = JobDetails(application: application)
        scanStore = JDScanStore(
            keyStore: keyStore, bundle: bundle, makeIntelligence: makeIntelligence)
        tailorStore = TailorStore(
            profileStore: profileStore, keyStore: keyStore, bundle: bundle,
            makeIntelligence: makeIntelligence)
    }

    func start() async {
        phase = .scanning
        matchReview = nil
        // The [TAILOR-3] refusal keeps its place before any service call —
        // the scan must not spend a request on a Profile with nothing to
        // select from ([TAILOR-43]).
        guard
            let profile = profileStore.profile,
            profile.roles.contains(where: { !$0.achievements.isEmpty })
                || !profile.projects.isEmpty
        else {
            phase = .tailorFailed(.achievementsRequired)
            return
        }
        await scanStore.scan(application)
        switch scanStore.phase {
        case .scanned:
            guard let match = application.match else {
                phase = .scanFailed(.requestFailed(detail: "the scan stored no Match"))
                return
            }
            matchReview = MatchReviewModel(match: match, suggestions: scanStore.suggestions)
            phase = .matchReview
        case .failed(let error):
            // No fallback path — not the raw JD, not the stale Match
            // (decisions/0014).
            phase = .scanFailed(error)
        case .idle, .scanning:
            phase = .scanFailed(.requestFailed(detail: "the scan never completed"))
        }
    }

    func confirmMatchReview() async {
        guard phase == .matchReview else { return }
        if let matchReview {
            do {
                confirmationNotes = try MatchReviewConfirmation.apply(
                    matchReview, to: application)
            } catch {
                // A failed confirmation write must not misground the run
                // that follows it.
                phase = .tailorFailed(.requestFailed)
                return
            }
        }
        phase = .tailoring
        // The run grounds in the Match as confirmation left it
        // ([TAILOR-49], [TAILOR-52]) and aims at what history has proven
        // fits ([TAILOR-57]).
        await tailorStore.startRun(
            details,
            matchedTagNames: application.match?.matchedTags.map(\.name) ?? [],
            budget: fitHistoryBudget())
        switch tailorStore.phase {
        case .review:
            phase = .review
        case .failed(let error):
            phase = .tailorFailed(error)
        case .idle, .running:
            phase = .tailorFailed(.requestFailed)
        }
    }

    /// Dismissal writes nothing — pool and Match stay exactly as the scan
    /// left them ([TAILOR-50]); the view owns the actual dismiss.
    func cancelMatchReview() {
        matchReview = nil
    }

    /// Retry re-runs from the scan, never mid-flow (decisions/0014).
    func retry() async {
        await start()
    }

    // The confirmation write path lives in `MatchReviewConfirmation` —
    // shared with the application detail's Match section (PipelineBoard
    // decisions/0009).

    /// Every Application's FitMetrics feeds the budget — each records its
    /// latest export ([CVEXPORT-30]); the pure helper does the qualifying
    /// (decisions/0016).
    private func fitHistoryBudget() -> ContentBudget? {
        guard let context = application.modelContext,
            let applications = try? context.fetch(FetchDescriptor<Application>())
        else { return nil }
        return ContentBudget.from(applications.compactMap(\.fitMetrics))
    }
}

/// The Match review's presented state ([TAILOR-46]): a snapshot of the
/// persisted Match plus the scan's transient suggestions, each a checkbox.
/// Toggling recomputes the score offline ([TAILOR-47]); nothing here writes.
@MainActor
@Observable
final class MatchReviewModel {
    struct SuggestionItem: Identifiable {
        let proposal: TagSuggestionProposal
        /// Unchecked on entry: a suggestion writes a vocabulary claim into
        /// the pool, and claiming a skill is opt-in ([TAILOR-46]).
        var isAccepted = false
        var id: Int { proposal.id }
    }

    let matchedTagNames: [String]
    let vocabularyGaps: [String]
    var suggestions: [SuggestionItem]

    init(match: Match, suggestions: [TagSuggestionProposal]) {
        matchedTagNames = match.matchedTags.map(\.name)
        vocabularyGaps = match.vocabularyGaps
        self.suggestions = suggestions.map { SuggestionItem(proposal: $0) }
    }

    /// [TAILOR-41]'s derivation over the snapshot, live: while checked, a
    /// resolving suggestion counts its gap as matched — distinct gaps only,
    /// so two suggestions dissolving one gap move the score once
    /// ([TAILOR-47]). Deterministic and offline; no service call anywhere.
    var score: Int? {
        let resolvedGaps = Set(suggestions.filter(\.isAccepted).compactMap(\.proposal.resolves))
        return Match.score(
            matched: matchedTagNames.count + resolvedGaps.count,
            gaps: vocabularyGaps.count - resolvedGaps.count)
    }
}

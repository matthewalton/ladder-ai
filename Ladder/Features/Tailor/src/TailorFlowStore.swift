import Foundation
import SwiftData

@MainActor
@Observable
final class TailorFlowStore {
    enum Phase: Equatable {
        case scanning
        case matchReview
        case tailoring
        case review
        case scanFailed(JDScanError)
        case tailorFailed(TailorError)
    }

    private(set) var phase: Phase = .scanning
    private(set) var matchReview: MatchReviewModel?
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
                phase = .tailorFailed(.requestFailed)
                return
            }
        }
        phase = .tailoring
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

    func cancelMatchReview() {
        matchReview = nil
    }

    func retry() async {
        await start()
    }

    private func fitHistoryBudget() -> ContentBudget? {
        guard let context = application.modelContext,
            let applications = try? context.fetch(FetchDescriptor<Application>())
        else { return nil }
        return ContentBudget.from(applications.compactMap(\.fitMetrics))
    }
}

@MainActor
@Observable
final class MatchReviewModel {
    struct SuggestionItem: Identifiable {
        let proposal: TagSuggestionProposal
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

    var score: Int? {
        let resolvedGaps = Set(suggestions.filter(\.isAccepted).compactMap(\.proposal.resolves))
        return Match.score(
            matched: matchedTagNames.count + resolvedGaps.count,
            gaps: vocabularyGaps.count - resolvedGaps.count)
    }
}

import Foundation

/// MVVM-lite store for the import flow: file → extraction → proposal →
/// review → merge (SPEC.md). One import runs at a time.
@MainActor
@Observable
final class ImportStore {
    enum Phase: Equatable {
        case idle
        /// Extraction and the proposal request, in flight.
        case importing
        /// A proposal is held for review; `review` is non-nil.
        case review
        case merging
        case merged
        case failed(ImportError)
    }

    private(set) var phase: Phase = .idle
    private(set) var review: ImportReview?

    private let profileStore: ProfileStore
    private let keyStore: any APIKeyStore
    private let bundle: Bundle
    private let makeIntelligence: (String) -> any IntelligenceService

    /// `makeIntelligence` receives the stored API key and returns the service
    /// for this run — the live Anthropic service in production, a fixture in
    /// tests and previews (decisions/0005, Tailor decisions/0002).
    init(
        profileStore: ProfileStore,
        keyStore: any APIKeyStore,
        bundle: Bundle = .main,
        makeIntelligence: @escaping (String) -> any IntelligenceService = {
            AnthropicIntelligenceService(apiKey: $0)
        }
    ) {
        self.profileStore = profileStore
        self.keyStore = keyStore
        self.bundle = bundle
        self.makeIntelligence = makeIntelligence
    }

    func startImport(of url: URL) async {
        // Refused before extraction: import merges into the Profile and never
        // creates it ([CVIMPORT-3], decisions/0001).
        guard profileStore.profile != nil else {
            phase = .failed(.profileRequired)
            return
        }
        // Refused before extraction and before any service call: no stored
        // key means no live run, and never a fixture fallback
        // ([CVIMPORT-14], Tailor decisions/0002).
        guard let key = try? keyStore.readKey(), !key.isEmpty else {
            phase = .failed(.apiKeyRequired)
            return
        }
        phase = .importing
        review = nil
        do {
            let text = try CVTextExtractor.extractText(from: url)
            let prompt = try ImportPrompt.text(from: bundle)
            let service = makeIntelligence(key)
            let response: Data
            do {
                response = try await service.complete(
                    IntelligenceRequest(prompt: prompt, payload: text)
                )
            } catch {
                // Transport failure is not validation failure — the detail
                // makes the retry informed ([CVIMPORT-16], decisions/0004).
                throw ImportError.requestFailed(detail: Self.requestFailureDetail(for: error))
            }
            let proposal = try ImportProposal(json: response)
            review = ImportReview(proposal: proposal)
            phase = .review
        } catch {
            // Only a missing bundled prompt reaches this fallback — a
            // packaging bug; every other failure is already an ImportError.
            phase = .failed(
                (error as? ImportError)
                    ?? .proposalInvalid(reason: "the import prompt could not be loaded from the app bundle")
            )
        }
    }

    private static func requestFailureDetail(for error: Error) -> String {
        switch error {
        case AnthropicIntelligenceService.LiveServiceError.httpFailure(let status):
            "HTTP \(status)"
        case AnthropicIntelligenceService.LiveServiceError.emptyResponse:
            "the service returned an empty response"
        default:
            (error as NSError).localizedDescription
        }
    }

    /// The merge (slice CONTEXT.md): the review's included items land in the
    /// existing Profile through the `ProfileStore` pathway ([CVIMPORT-5]–
    /// [CVIMPORT-8]). Nothing lands without this confirmation; not-imported
    /// sections are never written anywhere ([CVIMPORT-9]).
    func confirmReview() {
        guard phase == .review, let review else { return }
        phase = .merging
        do {
            for role in review.roles where role.included {
                let added = try profileStore.addRole(
                    company: role.proposed.company,
                    title: role.proposed.title,
                    start: role.proposed.start,
                    end: role.proposed.end
                )
                for achievement in role.achievements where achievement.included {
                    let addedAchievement = try profileStore.addAchievement(
                        to: added, text: achievement.proposed.text
                    )
                    try profileStore.updateAchievementDetails(
                        addedAchievement,
                        impactMetric: achievement.proposed.impactMetric,
                        tech: achievement.proposed.tech,
                        strengthNotes: nil
                    )
                    for skill in achievement.skills where skill.included {
                        try profileStore.tag(addedAchievement, skillNamed: skill.name)
                    }
                }
            }
            self.review = nil
            phase = .merged
        } catch {
            // The store only throws here when the Profile vanished mid-review.
            self.review = nil
            phase = .failed(.profileRequired)
        }
    }

    /// Back to idle — after a failure or a completed merge.
    func reset() {
        phase = .idle
        review = nil
    }
}

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
    private let intelligence: any IntelligenceService
    private let bundle: Bundle

    init(profileStore: ProfileStore, intelligence: any IntelligenceService, bundle: Bundle = .main) {
        self.profileStore = profileStore
        self.intelligence = intelligence
        self.bundle = bundle
    }

    func startImport(of url: URL) async {
        // Refused before extraction: import merges into the Profile and never
        // creates it ([CVIMPORT-3], decisions/0001).
        guard profileStore.profile != nil else {
            phase = .failed(.profileRequired)
            return
        }
        phase = .importing
        review = nil
        do {
            let text = try CVTextExtractor.extractText(from: url)
            let prompt = try ImportPrompt.text(from: bundle)
            let response = try await intelligence.complete(
                IntelligenceRequest(prompt: prompt, payload: text)
            )
            let proposal = try ImportProposal(json: response)
            review = ImportReview(proposal: proposal)
            phase = .review
        } catch {
            // A missing bundled prompt surfaces here too; it can only be a
            // packaging bug, and proposalInvalid is the honest visible state.
            phase = .failed((error as? ImportError) ?? .proposalInvalid)
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

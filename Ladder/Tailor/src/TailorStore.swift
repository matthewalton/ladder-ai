import Foundation

/// MVVM-lite store for the tailor flow: job details → payload → intelligence
/// service → validated tailor result → review (SPEC.md). One run at a time;
/// everything is transient (decisions/0001).
@MainActor
@Observable
final class TailorStore {
    enum Phase: Equatable {
        case idle
        /// The tailor run (and any repair request) is in flight.
        case running
        /// A tailor result is held for review; `review` is non-nil.
        case review
        case failed(TailorError)
    }

    private(set) var phase: Phase = .idle
    private(set) var review: TailorReview?

    private let profileStore: ProfileStore
    private let keyStore: any APIKeyStore
    private let bundle: Bundle
    private let makeIntelligence: (String) -> any IntelligenceService

    /// `makeIntelligence` receives the stored API key and returns the service
    /// for this run — the live Anthropic service in production, a fixture in
    /// tests and previews (decisions/0002).
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

    func startRun(_ details: JobDetails) async {
        // Each refusal fires at start, before any service call
        // ([TAILOR-2]–[TAILOR-4]).
        guard !details.jobDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            phase = .failed(.jobDescriptionRequired)
            return
        }
        guard let profile = profileStore.profile,
            profile.roles.contains(where: { !$0.achievements.isEmpty })
        else {
            phase = .failed(.achievementsRequired)
            return
        }
        guard let key = try? keyStore.readKey(), !key.isEmpty else {
            phase = .failed(.apiKeyRequired)
            return
        }
        phase = .running
        review = nil
        do {
            let payload = try TailorPayload(profile: profile, details: details)
            let prompt = try TailorPrompt.text(from: bundle)
            let service = makeIntelligence(key)
            let validIDs = Set(payload.achievementsByID.keys)
            let request = IntelligenceRequest(prompt: prompt, payload: payload.json)
            let response = try await service.complete(request)
            let result: TailorResult
            do {
                result = try TailorResult(json: response, validAchievementIDs: validIDs)
            } catch let failure as TailorValidationFailure {
                // Exactly one repair request (decisions/0004): the original
                // request content, the invalid response, and the failure,
                // for the service to fix ([TAILOR-9]). A repair response
                // failing validation fails the run ([TAILOR-10]).
                let repair = IntelligenceRequest(
                    prompt: prompt,
                    payload: Self.repairPayload(
                        original: payload.json, response: response, failure: failure
                    )
                )
                let repairResponse = try await service.complete(repair)
                result = try TailorResult(json: repairResponse, validAchievementIDs: validIDs)
            }
            review = TailorReview(result: result, achievementsByID: payload.achievementsByID)
            phase = .review
        } catch is TailorValidationFailure {
            phase = .failed(.resultInvalid)
        } catch {
            // A missing bundled prompt or a transport failure — not an
            // invalid result.
            phase = .failed(.requestFailed)
        }
    }

    private static func repairPayload(
        original: String, response: Data, failure: TailorValidationFailure
    ) -> String {
        """
        Your previous response failed validation.

        Failure: \(failure.reason)

        Your previous response was:
        \(String(decoding: response, as: UTF8.self))

        Return corrected JSON for the original input, which follows.

        \(original)
        """
    }

    /// Back to idle — after a failure or a finished review.
    func reset() {
        phase = .idle
        review = nil
    }
}

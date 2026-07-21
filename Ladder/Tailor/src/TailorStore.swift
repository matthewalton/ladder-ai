import Foundation

/// One tailor run at a time; nothing a run produces is persisted.
@MainActor
@Observable
final class TailorStore {
    enum Phase: Equatable {
        case idle
        /// The repair request runs in this phase too — it never gets its own.
        case running
        /// `review` is non-nil.
        case review
        case failed(TailorError)
    }

    private(set) var phase: Phase = .idle
    private(set) var review: TailorReview?

    private let profileStore: ProfileStore
    private let keyStore: any APIKeyStore
    private let bundle: Bundle
    private let makeIntelligence: (String) -> any IntelligenceService

    /// `makeIntelligence` is the seam tests and previews use to substitute a
    /// fixture service.
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
        guard !details.jobDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            phase = .failed(.jobDescriptionRequired)
            return
        }
        // Selectable content: role achievements point by point, projects
        // whole (decisions/0007).
        guard let profile = profileStore.profile,
            profile.roles.contains(where: { !$0.achievements.isEmpty })
                || !profile.projects.isEmpty
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
            let validProjectIDs = Set(payload.projectsByID.keys)
            let request = IntelligenceRequest(prompt: prompt, payload: payload.json)
            let response = try await service.complete(request)
            let result: TailorResult
            do {
                result = try TailorResult(
                    json: response,
                    validAchievementIDs: validIDs,
                    validProjectIDs: validProjectIDs
                )
            } catch let failure as TailorValidationFailure {
                // Exactly one repair attempt; a repair response failing
                // validation fails the run.
                let repair = IntelligenceRequest(
                    prompt: prompt,
                    payload: Self.repairPayload(
                        original: payload.json, response: response, failure: failure
                    )
                )
                let repairResponse = try await service.complete(repair)
                result = try TailorResult(
                    json: repairResponse,
                    validAchievementIDs: validIDs,
                    validProjectIDs: validProjectIDs
                )
            }
            review = TailorReview(
                result: result,
                achievementsByID: payload.achievementsByID,
                projectsByID: payload.projectsByID
            )
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

    func reset() {
        phase = .idle
        review = nil
    }
}

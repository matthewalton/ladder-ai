import Foundation
import SwiftData

/// One debrief run at a time; a valid result is persisted onto the Stage,
/// replacing any existing debrief ([DEBRIEF-15]).
@MainActor
@Observable
final class DebriefStore {
    enum Phase: Equatable {
        case idle
        /// The repair request runs in this phase too — it never gets its own.
        case running
        /// The validated debrief is persisted on the Stage.
        case generated
        case failed(DebriefError)
    }

    private(set) var phase: Phase = .idle

    private let context: ModelContext
    private let profileStore: ProfileStore
    private let keyStore: any APIKeyStore
    private let bundle: Bundle
    private let makeIntelligence: (String) -> any IntelligenceService

    /// `makeIntelligence` is the seam tests and previews use to substitute a
    /// fixture service.
    init(
        container: ModelContainer,
        profileStore: ProfileStore,
        keyStore: any APIKeyStore,
        bundle: Bundle = .main,
        makeIntelligence: @escaping (String) -> any IntelligenceService = {
            AnthropicIntelligenceService(apiKey: $0)
        }
    ) {
        self.context = ModelContext(container)
        self.profileStore = profileStore
        self.keyStore = keyStore
        self.bundle = bundle
        self.makeIntelligence = makeIntelligence
    }

    /// Generation is an explicit user action — nothing calls this
    /// automatically. `generatedAt` is passed in; tests never read the clock.
    func generate(for stage: Stage, generatedAt: Date = .now) async {
        let notesOverview = stage.transcript?.notesSummary?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !notesOverview.isEmpty else {
            phase = .failed(.notesRequired)
            return
        }
        guard let key = try? keyStore.readKey(), !key.isEmpty else {
            phase = .failed(.apiKeyRequired)
            return
        }
        phase = .running
        do {
            let payload = try DebriefPayload(
                stage: stage, notesOverview: notesOverview, profile: profileStore.profile)
            let prompt = try DebriefPrompt.text(from: bundle)
            let service = makeIntelligence(key)
            let request = IntelligenceRequest(prompt: prompt, payload: payload.json)
            let response = try await service.complete(request)
            let result: DebriefResult
            do {
                result = try DebriefResult(
                    json: response, notesOverview: notesOverview,
                    achievementCount: payload.achievements.count)
            } catch let failure as DebriefValidationFailure {
                // Exactly one repair attempt; a repair response failing
                // validation fails the run (decisions/0002).
                let repair = IntelligenceRequest(
                    prompt: prompt,
                    payload: Self.repairPayload(
                        original: payload.json, response: response, failure: failure
                    )
                )
                let repairResponse = try await service.complete(repair)
                result = try DebriefResult(
                    json: repairResponse, notesOverview: notesOverview,
                    achievementCount: payload.achievements.count)
            }
            try persist(result, on: stage, achievements: payload.achievements, generatedAt: generatedAt)
            phase = .generated
        } catch is DebriefValidationFailure {
            phase = .failed(.resultInvalid)
        } catch {
            // A missing bundled prompt or a transport failure — not an
            // invalid result.
            phase = .failed(.requestFailed)
        }
    }

    /// Writes the validated result onto the Stage, replacing any existing
    /// debrief — the old record is deleted, never orphaned ([DEBRIEF-15]).
    private func persist(
        _ result: DebriefResult, on stage: Stage, achievements: [Achievement], generatedAt: Date
    ) throws {
        let context = stage.modelContext ?? self.context
        // Payload achievements may live in the ProfileStore's context;
        // relationships are wired within one context, so resolve each into
        // the persisting one by its store identity.
        let resolved = achievements.map { achievement in
            context.model(for: achievement.persistentModelID) as? Achievement ?? achievement
        }
        if let existing = stage.debrief {
            context.delete(existing)
        }
        let debrief = Debrief(
            generatedAt: generatedAt,
            themes: result.themes,
            signals: result.signals,
            drills: result.drills
        )
        context.insert(debrief)
        for (index, entry) in result.questions.enumerated() {
            let question = DebriefQuestion(
                question: entry.question,
                answerSummary: entry.answerSummary,
                quality: entry.quality,
                quote: entry.quote,
                sortIndex: index,
                missedAmmo: entry.missedAmmo.map { resolved[$0] }
            )
            context.insert(question)
            question.debrief = debrief
        }
        stage.debrief = debrief
        try context.save()
    }

    private static func repairPayload(
        original: String, response: Data, failure: DebriefValidationFailure
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
    }
}

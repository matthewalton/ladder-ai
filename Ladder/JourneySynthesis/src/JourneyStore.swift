import Foundation
import SwiftData

/// One journey run at a time; a valid result is persisted onto the
/// Application, replacing any existing narrative ([JOURNEY-12]).
@MainActor
@Observable
final class JourneyStore {
    enum Phase: Equatable {
        case idle
        /// The repair request runs in this phase too — it never gets its own.
        case running
        /// The validated narrative is persisted on the Application.
        case generated
        case failed(JourneyError)
    }

    private(set) var phase: Phase = .idle

    private let context: ModelContext
    private let keyStore: any APIKeyStore
    private let bundle: Bundle
    private let makeIntelligence: (String) -> any IntelligenceService

    /// `makeIntelligence` is the seam tests and previews use to substitute a
    /// fixture service. No ProfileStore: the journey payload reads only the
    /// Application and its Stage chain ([JOURNEY-8]).
    init(
        container: ModelContainer,
        keyStore: any APIKeyStore,
        bundle: Bundle = .main,
        makeIntelligence: @escaping (String) -> any IntelligenceService = {
            AnthropicIntelligenceService(apiKey: $0)
        }
    ) {
        self.context = ModelContext(container)
        self.keyStore = keyStore
        self.bundle = bundle
        self.makeIntelligence = makeIntelligence
    }

    /// Generation is an explicit user action — nothing calls this
    /// automatically, and reaching `.offer` never generates by itself.
    /// `generatedAt` is passed in; tests never read the clock.
    func generate(for application: Application, generatedAt: Date = .now) async {
        // The offer-time gate, store side ([JOURNEY-5]).
        guard application.status == .offer else {
            phase = .failed(.offerRequired)
            return
        }
        guard let key = try? keyStore.readKey(), !key.isEmpty else {
            phase = .failed(.apiKeyRequired)
            return
        }
        phase = .running
        do {
            let payload = try JourneyPayload(application: application)
            let prompt = try JourneyPrompt.text(from: bundle)
            let service = makeIntelligence(key)
            let request = IntelligenceRequest(prompt: prompt, payload: payload.json)
            let response = try await service.complete(request)
            let result: JourneyResult
            do {
                result = try JourneyResult(json: response)
            } catch let failure as JourneyValidationFailure {
                // Exactly one repair attempt; a repair response failing
                // validation fails the run ([JOURNEY-10], [JOURNEY-11]).
                let repair = IntelligenceRequest(
                    prompt: prompt,
                    payload: Self.repairPayload(
                        original: payload.json, response: response, failure: failure
                    )
                )
                let repairResponse = try await service.complete(repair)
                result = try JourneyResult(json: repairResponse)
            }
            try persist(result, on: application, generatedAt: generatedAt)
            phase = .generated
        } catch is JourneyValidationFailure {
            phase = .failed(.resultInvalid)
        } catch {
            // A missing bundled prompt or a transport failure — not an
            // invalid result.
            phase = .failed(.requestFailed)
        }
    }

    /// Writes the validated result onto the Application, replacing any
    /// existing narrative — the old record is deleted, never orphaned
    /// ([JOURNEY-12]).
    private func persist(
        _ result: JourneyResult, on application: Application, generatedAt: Date
    ) throws {
        let context = application.modelContext ?? self.context
        if let existing = application.journeyNarrative {
            context.delete(existing)
        }
        let narrative = JourneyNarrative(text: result.narrative, generatedAt: generatedAt)
        context.insert(narrative)
        application.journeyNarrative = narrative
        try context.save()
    }

    private static func repairPayload(
        original: String, response: Data, failure: JourneyValidationFailure
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

    /// The confirmed remove ([JOURNEY-16]): deletes the narrative; the
    /// Application and its Stages survive untouched. The confirmation dialog
    /// is the view's; the store just deletes. An Application without a
    /// narrative is a no-op.
    func removeNarrative(from application: Application) throws {
        guard let narrative = application.journeyNarrative else { return }
        let context = application.modelContext ?? self.context
        context.delete(narrative)
        try context.save()
        phase = .idle
    }
}

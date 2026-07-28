import Foundation
import SwiftData

@MainActor
@Observable
final class JourneyStore {
    enum Phase: Equatable {
        case idle
        case running
        case generated
        case failed(JourneyError)
    }

    private(set) var phase: Phase = .idle

    private let context: ModelContext
    private let keyStore: any APIKeyStore
    private let bundle: Bundle
    private let makeIntelligence: (String) -> any IntelligenceService

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

    func generate(for application: Application, generatedAt: Date = .now) async {
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
            phase = .failed(.requestFailed)
        }
    }

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

    func removeNarrative(from application: Application) throws {
        guard let narrative = application.journeyNarrative else { return }
        let context = application.modelContext ?? self.context
        context.delete(narrative)
        try context.save()
        phase = .idle
    }
}

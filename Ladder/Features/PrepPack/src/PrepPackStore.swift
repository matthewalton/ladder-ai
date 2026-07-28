import Foundation
import SwiftData

@MainActor
@Observable
final class PrepPackStore {
    enum Phase: Equatable {
        case idle
        case running
        case generated
        case failed(PrepPackError)
    }

    private(set) var phase: Phase = .idle

    private let context: ModelContext
    private let profileStore: ProfileStore
    private let keyStore: any APIKeyStore
    private let bundle: Bundle
    private let makeIntelligence: (String) -> any IntelligenceService

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

    func generate(for stage: Stage, generatedAt: Date = .now) async {
        let jobDescription = stage.application?.jobDescription
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let prepContext = stage.prepContext
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let priorDebriefs = PrepPackPayload.priorDebriefs(for: stage)
        guard !jobDescription.isEmpty || !prepContext.isEmpty || !priorDebriefs.isEmpty else {
            phase = .failed(.inputsRequired)
            return
        }
        guard let key = try? keyStore.readKey(), !key.isEmpty else {
            phase = .failed(.apiKeyRequired)
            return
        }
        phase = .running
        do {
            let payload = try PrepPackPayload(
                stage: stage, priorDebriefs: priorDebriefs, profile: profileStore.profile)
            let prompt = try PrepPackPrompt.text(from: bundle)
            let service = makeIntelligence(key)
            let request = IntelligenceRequest(prompt: prompt, payload: payload.json)
            let response = try await service.complete(request)
            let mockTasksWanted = stage.kind.isTechnicalType
            let result: PrepPackResult
            do {
                result = try PrepPackResult(
                    json: response, achievementCount: payload.achievements.count,
                    mockTasksWanted: mockTasksWanted)
            } catch let failure as PrepPackValidationFailure {
                let repair = IntelligenceRequest(
                    prompt: prompt,
                    payload: Self.repairPayload(
                        original: payload.json, response: response, failure: failure
                    )
                )
                let repairResponse = try await service.complete(repair)
                result = try PrepPackResult(
                    json: repairResponse, achievementCount: payload.achievements.count,
                    mockTasksWanted: mockTasksWanted)
            }
            try persist(result, on: stage, achievements: payload.achievements, generatedAt: generatedAt)
            phase = .generated
        } catch is PrepPackValidationFailure {
            phase = .failed(.resultInvalid)
        } catch {
            phase = .failed(.requestFailed)
        }
    }

    private func persist(
        _ result: PrepPackResult, on stage: Stage, achievements: [Achievement], generatedAt: Date
    ) throws {
        let context = stage.modelContext ?? self.context
        // Payload achievements may live in the ProfileStore's context; relationships
        // are wired within one context, so resolve each into the persisting one.
        let resolved = achievements.map { achievement in
            context.model(for: achievement.persistentModelID) as? Achievement ?? achievement
        }
        if let existing = stage.prepPack {
            context.delete(existing)
        }
        let pack = PrepPack(
            generatedAt: generatedAt,
            likelyQuestions: result.likelyQuestions,
            companyBrief: result.companyBrief,
            mockTasks: result.mockTasks ?? []
        )
        context.insert(pack)
        for (index, point) in result.talkingPoints.enumerated() {
            let talkingPoint = PrepTalkingPoint(
                text: point.text,
                sortIndex: index,
                achievements: point.achievements.map { resolved[$0] }
            )
            context.insert(talkingPoint)
            talkingPoint.prepPack = pack
        }
        stage.prepPack = pack
        try context.save()
    }

    private static func repairPayload(
        original: String, response: Data, failure: PrepPackValidationFailure
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

    func removePrepPack(from stage: Stage) throws {
        guard let pack = stage.prepPack else { return }
        let context = stage.modelContext ?? self.context
        context.delete(pack)
        try context.save()
        phase = .idle
    }
}

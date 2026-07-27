import Foundation
import SwiftData
import Testing

@testable import Ladder

/// The canned journey result loads from the app bundle's Fixtures folder
/// (tests run in the app host). No network anywhere.
@MainActor
struct JourneyFlowTests {
    /// The narrative text inside the bundled journey-result fixture.
    static let fixtureNarrativeOpening =
        "The Summit Labs climb opened quietly"

    /// An Application at `.offer` with a two-Stage chain, the first Stage
    /// debriefed — the thinnest realistic chain to synthesise over.
    private func makeOfferApplication(
        in container: ModelContainer,
        status: ApplicationStatus = .offer
    ) throws -> Application {
        let context = ModelContext(container)
        let application = Application(
            company: "Summit Labs", roleTitle: "Platform Engineer",
            jobDescription: "Own platform reliability.", status: status,
            appliedAt: Date(timeIntervalSince1970: 1_770_100_000))
        context.insert(application)

        let screen = Stage(
            kind: .screen,
            scheduledAt: Date(timeIntervalSince1970: 1_771_000_000),
            outcome: .passed,
            sortIndex: 0)
        context.insert(screen)
        screen.application = application
        let debrief = Debrief(
            generatedAt: Date(timeIntervalSince1970: 1_772_100_000),
            themes: [GroundedRemark(text: "Systems depth landed", quote: "incident timeline")],
            signals: [GroundedRemark(text: "On-call ownership probed", quote: "on-call rotation")],
            drills: ["Practice the STAR arc for the outage story"])
        context.insert(debrief)
        let question = DebriefQuestion(
            question: "How did you handle the payments outage?",
            answerSummary: "Walked the timeline",
            quality: .adequate,
            quote: "Walked through the incident timeline",
            sortIndex: 0)
        context.insert(question)
        question.debrief = debrief
        screen.debrief = debrief

        let technical = Stage(
            kind: .technical,
            scheduledAt: Date(timeIntervalSince1970: 1_772_500_000),
            outcome: .passed,
            sortIndex: 1)
        context.insert(technical)
        technical.application = application

        try context.save()
        return application
    }

    private func makeJourneyStore(
        container: ModelContainer,
        service: FixtureIntelligenceService,
        keyStore: any APIKeyStore = InMemoryAPIKeyStore(key: "sk-test")
    ) -> JourneyStore {
        JourneyStore(
            container: container,
            keyStore: keyStore,
            makeIntelligence: { _ in service }
        )
    }

    @Test("[JOURNEY-1] a generated journey narrative is still on the Application after the app relaunches")
    func generatedNarrativeSurvivesRelaunch() async throws {
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }

        do {
            let container = try ProfileStore.container(at: url)
            let application = try makeOfferApplication(in: container)
            let store = makeJourneyStore(
                container: container,
                service: FixtureIntelligenceService.journeyFixture()
            )

            await store.generate(
                for: application, generatedAt: Date(timeIntervalSince1970: 1_773_000_000))

            #expect(store.phase == .generated)
        }

        let reopened = try ProfileStore.container(at: url)
        let context = ModelContext(reopened)
        let application = try #require(try context.fetch(FetchDescriptor<Application>()).first)
        let narrative = try #require(
            application.journeyNarrative, "the narrative is still on the Application")
        #expect(narrative.generatedAt == Date(timeIntervalSince1970: 1_773_000_000))
        #expect(
            narrative.text.hasPrefix(Self.fixtureNarrativeOpening),
            "the fixture narrative rode through persistence intact")
    }

    /// The valid fixture bytes, for invalid-then-valid repair sequences.
    private var validJSON: Data {
        get throws {
            try Data(contentsOf: #require(
                Bundle.main.url(forResource: "journey-result", withExtension: "json", subdirectory: "Fixtures"),
                "journey-result.json missing from the bundled Fixtures folder"
            ))
        }
    }

    /// The fixture's narrative string, decoded — the verbatim reference.
    private var fixtureNarrative: String {
        get throws {
            try JSONDecoder().decode(JourneyResult.self, from: validJSON).narrative
        }
    }

    /// Parses right off the wire but fails the schema check.
    private var wrongShapeResponse: Data {
        Data(#"{"story": "a field the schema does not have"}"#.utf8)
    }

    /// Schema-shaped but empty — fails the non-empty check.
    private var emptyNarrativeResponse: Data {
        Data(#"{"narrative": "  \n "}"#.utf8)
    }

    private func payloadObject(
        of request: IntelligenceRequest
    ) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: Data(request.payload.utf8)) as? [String: Any],
            "the payload is a JSON object")
    }

    @Test("[JOURNEY-5] generating a narrative for an Application not at offer is refused")
    func notAtOfferIsRefused() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let service = FixtureIntelligenceService.journeyFixture()
        let store = makeJourneyStore(container: container, service: service)
        let application = try makeOfferApplication(in: container, status: .active)

        await store.generate(
            for: application, generatedAt: Date(timeIntervalSince1970: 1_773_000_000))

        #expect(store.phase == .failed(.offerRequired))
        #expect(application.journeyNarrative == nil)
        #expect(await service.recordedRequests.isEmpty, "refused before any service call")
    }

    @Test("[JOURNEY-6] generating a narrative with no API key stored is refused")
    func noAPIKeyIsRefused() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let service = FixtureIntelligenceService.journeyFixture()
        let store = makeJourneyStore(
            container: container, service: service,
            keyStore: InMemoryAPIKeyStore(key: nil))
        let application = try makeOfferApplication(in: container)

        await store.generate(
            for: application, generatedAt: Date(timeIntervalSince1970: 1_773_000_000))

        #expect(store.phase == .failed(.apiKeyRequired))
        #expect(application.journeyNarrative == nil)
        #expect(await service.recordedRequests.isEmpty, "refused before any service call")
    }

    @Test("[JOURNEY-7] the journey request contains the versioned journey prompt")
    func journeyRequestCarriesTheBundledPrompt() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let service = FixtureIntelligenceService.journeyFixture()
        let store = makeJourneyStore(container: container, service: service)
        let application = try makeOfferApplication(in: container)

        await store.generate(
            for: application, generatedAt: Date(timeIntervalSince1970: 1_773_000_000))

        let request = try #require(await service.recordedRequests.first)
        #expect(
            request.prompt == (try JourneyPrompt.text(from: .main)),
            "the prompt is the bundled Prompts/journey.md, verbatim")

        let payload = try payloadObject(of: request)
        let applicationPart = try #require(payload["application"] as? [String: Any])
        #expect(applicationPart["company"] as? String == "Summit Labs")
        #expect(applicationPart["roleTitle"] as? String == "Platform Engineer")
        #expect(
            applicationPart["appliedAt"] as? String != nil,
            "the applied date travels as an ISO 8601 string")
        #expect(payload["stages"] as? [[String: Any]] != nil)
    }

    @Test("[JOURNEY-8] the journey payload lists every Stage in chain order with its debrief content where present")
    func journeyPayloadWalksTheFullChain() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let service = FixtureIntelligenceService.journeyFixture()
        let store = makeJourneyStore(container: container, service: service)
        let application = try makeOfferApplication(in: container)
        // A third, undebriefed stage after the chain the helper builds —
        // inserted out of order to prove sortIndex, not insert order, rules.
        let context = try #require(application.modelContext)
        let final = Stage(kind: .final, outcome: .passed, sortIndex: 2)
        context.insert(final)
        final.application = application
        try context.save()

        await store.generate(
            for: application, generatedAt: Date(timeIntervalSince1970: 1_773_000_000))

        let request = try #require(await service.recordedRequests.first)
        let payload = try payloadObject(of: request)
        let stages = try #require(payload["stages"] as? [[String: Any]])
        #expect(
            stages.map { $0["kind"] as? String } == ["screen", "technical", "final"],
            "every Stage appears, in sortIndex order")

        let screen = try #require(stages.first)
        let debrief = try #require(
            screen["debrief"] as? [String: Any], "the debriefed stage carries its debrief")
        #expect(debrief["themes"] as? [String] == ["Systems depth landed"])
        #expect(debrief["signals"] as? [String] == ["On-call ownership probed"])
        #expect(debrief["drills"] as? [String] == ["Practice the STAR arc for the outage story"])
        let questions = try #require(debrief["questions"] as? [[String: Any]])
        #expect(questions.first?["question"] as? String == "How did you handle the payments outage?")
        #expect(questions.first?["quality"] as? String == "adequate")

        #expect(
            stages[1]["debrief"] == nil || stages[1]["debrief"] is NSNull,
            "an undebriefed stage still appears, without debrief content")
        #expect(stages[2]["debrief"] == nil || stages[2]["debrief"] is NSNull)
    }

    @Test("[JOURNEY-9] the narrative carries the service's text verbatim")
    func narrativeIsPersistedVerbatim() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let service = FixtureIntelligenceService.journeyFixture()
        let store = makeJourneyStore(container: container, service: service)
        let application = try makeOfferApplication(in: container)

        await store.generate(
            for: application, generatedAt: Date(timeIntervalSince1970: 1_773_000_000))

        let narrative = try #require(application.journeyNarrative)
        #expect(
            narrative.text == (try fixtureNarrative),
            "persisted as returned — never re-derived or reworded")
    }

    @Test("[JOURNEY-10] a response failing validation triggers exactly one repair request")
    func invalidResponseTriggersOneRepair() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let service = FixtureIntelligenceService(
            returning: [wrongShapeResponse, try validJSON])
        let store = makeJourneyStore(container: container, service: service)
        let application = try makeOfferApplication(in: container)

        await store.generate(
            for: application, generatedAt: Date(timeIntervalSince1970: 1_773_000_000))

        #expect(store.phase == .generated, "a valid repair response produces the narrative as normal")
        #expect(application.journeyNarrative?.text == (try fixtureNarrative))
        let requests = await service.recordedRequests
        #expect(requests.count == 2, "exactly one repair — two requests, never three")
        let repair = try #require(requests.last)
        #expect(repair.payload.contains("did not match the journey result schema"))
        #expect(
            repair.payload.contains(#""story""#),
            "the repair request carries the invalid response")
        let original = try #require(requests.first)
        #expect(
            repair.payload.contains(original.payload),
            "the repair request carries the original request content")

        // An empty narrative is invalid too, and repairs the same way.
        let second = try ProfileStore.container(inMemory: true)
        let emptyService = FixtureIntelligenceService(
            returning: [emptyNarrativeResponse, try validJSON])
        let secondStore = makeJourneyStore(container: second, service: emptyService)
        let secondApplication = try makeOfferApplication(in: second)
        await secondStore.generate(
            for: secondApplication, generatedAt: Date(timeIntervalSince1970: 1_773_000_000))
        #expect(secondStore.phase == .generated)
        #expect(await emptyService.recordedRequests.count == 2)
    }

    @Test("[JOURNEY-11] a repair response failing validation fails the run")
    func failedRepairFailsTheRun() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let service = FixtureIntelligenceService(
            returning: [wrongShapeResponse, emptyNarrativeResponse])
        let store = makeJourneyStore(container: container, service: service)
        let application = try makeOfferApplication(in: container)
        // A narrative already on the Application stays exactly as it was.
        let context = try #require(application.modelContext)
        let existing = JourneyNarrative(
            text: "The climb as first told.",
            generatedAt: Date(timeIntervalSince1970: 1_772_900_000))
        context.insert(existing)
        application.journeyNarrative = existing
        try context.save()

        await store.generate(
            for: application, generatedAt: Date(timeIntervalSince1970: 1_773_000_000))

        #expect(store.phase == .failed(.resultInvalid), "the failed state names the reason")
        #expect(await service.recordedRequests.count == 2)
        #expect(
            application.journeyNarrative?.text == "The climb as first told.",
            "nothing is written on a failed run")
        #expect(
            application.journeyNarrative?.generatedAt
                == Date(timeIntervalSince1970: 1_772_900_000))
    }

    @Test("[JOURNEY-12] generating a narrative for an Application that already has one replaces the existing narrative")
    func regeneratingReplacesTheExistingNarrative() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let service = FixtureIntelligenceService.journeyFixture()
        let store = makeJourneyStore(container: container, service: service)
        let application = try makeOfferApplication(in: container)

        await store.generate(
            for: application, generatedAt: Date(timeIntervalSince1970: 1_773_000_000))
        await store.generate(
            for: application, generatedAt: Date(timeIntervalSince1970: 1_773_100_000))

        #expect(store.phase == .generated)
        let narrative = try #require(application.journeyNarrative)
        #expect(narrative.generatedAt == Date(timeIntervalSince1970: 1_773_100_000))
        let context = try #require(application.modelContext)
        #expect(
            try context.fetch(FetchDescriptor<JourneyNarrative>()).count == 1,
            "the old record is deleted, never orphaned")
    }

    @Test("[JOURNEY-13] a journey result wrapped in a markdown code fence produces a narrative")
    func fencedResultProducesANarrative() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let fenced = Data("```json\n\(String(decoding: try validJSON, as: UTF8.self))\n```".utf8)
        let service = FixtureIntelligenceService(returning: fenced)
        let store = makeJourneyStore(container: container, service: service)
        let application = try makeOfferApplication(in: container)

        await store.generate(
            for: application, generatedAt: Date(timeIntervalSince1970: 1_773_000_000))

        #expect(store.phase == .generated)
        #expect(application.journeyNarrative?.text == (try fixtureNarrative))
        #expect(
            await service.recordedRequests.count == 1,
            "a formatting quirk never consumes the single repair request")
    }
}

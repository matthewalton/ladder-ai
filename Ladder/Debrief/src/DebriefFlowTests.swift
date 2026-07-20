import Foundation
import SwiftData
import Testing

@testable import Ladder

/// The canned debrief result loads from the app bundle's Fixtures folder
/// (tests run in the app host). No network anywhere.
@MainActor
struct DebriefFlowTests {
    /// The notes overview every fixture quote is grounded in — quotes in
    /// debrief-result.json are exact substrings of this text.
    static let notesOverview = """
        ## Payments outage
        - Walked through the incident timeline and on-call rotation
        - Asked how the team measured recovery time

        ## CI pipeline
        - Discussed build times and flaky tests
        - Interviewer asked twice about Kubernetes experience
        """

    /// One role, three achievements — payload indices 0, 1, 2 in sort order.
    /// The bundled debrief-result fixture's missed ammo references index 2.
    private func makeProfileStore(container: ModelContainer) throws -> ProfileStore {
        let store = ProfileStore(container: container)
        try store.load()
        try store.createProfile(name: "Alex Climber", headline: "Staff Engineer")
        let role = try store.addRole(
            company: "Acme", title: "Senior Engineer",
            start: Date(timeIntervalSince1970: 1_600_000_000), end: nil
        )
        try store.addAchievement(to: role, text: "Cut CI build times across every product target")
        try store.addAchievement(to: role, text: "Shipped the offline sync engine")
        try store.addAchievement(to: role, text: "Led incident response for the payments outage")
        return store
    }

    /// An active Application with one technical Stage carrying attached notes.
    private func makeStage(
        in container: ModelContainer,
        notesOverview: String? = DebriefFlowTests.notesOverview
    ) throws -> Stage {
        let context = ModelContext(container)
        let application = Application(
            company: "Summit Labs", roleTitle: "Platform Engineer",
            jobDescription: "Own platform reliability.", status: .active)
        context.insert(application)
        let stage = Stage(kind: .technical, prepContext: "Expect systems questions.")
        context.insert(stage)
        stage.application = application
        if let notesOverview {
            let transcript = Transcript(
                recordedAt: Date(timeIntervalSince1970: 1_772_000_000),
                notesSummary: notesOverview)
            context.insert(transcript)
            stage.transcript = transcript
        }
        try context.save()
        return stage
    }

    private func makeDebriefStore(
        container: ModelContainer,
        profileStore: ProfileStore,
        service: FixtureIntelligenceService,
        keyStore: any APIKeyStore = InMemoryAPIKeyStore(key: "sk-test")
    ) -> DebriefStore {
        DebriefStore(
            container: container,
            profileStore: profileStore,
            keyStore: keyStore,
            makeIntelligence: { _ in service }
        )
    }

    @Test("[DEBRIEF-1] a generated debrief is still on the Stage after the app relaunches")
    func generatedDebriefSurvivesRelaunch() async throws {
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }

        do {
            let container = try ProfileStore.container(at: url)
            let profileStore = try makeProfileStore(container: container)
            let stage = try makeStage(in: container)
            let store = makeDebriefStore(
                container: container,
                profileStore: profileStore,
                service: FixtureIntelligenceService.debriefFixture()
            )

            await store.generate(
                for: stage, generatedAt: Date(timeIntervalSince1970: 1_772_100_000))

            #expect(store.phase == .generated)
        }

        let reopened = try ProfileStore.container(at: url)
        let context = ModelContext(reopened)
        let stage = try #require(try context.fetch(FetchDescriptor<Stage>()).first)
        let debrief = try #require(stage.debrief, "the debrief is still on the Stage")
        #expect(debrief.generatedAt == Date(timeIntervalSince1970: 1_772_100_000))
        let questions = debrief.orderedQuestions
        #expect(questions.count == 2)
        #expect(questions.first?.question == "How did you handle the payments outage?")
        #expect(questions.first?.quality == .adequate)
        #expect(
            questions.first?.missedAmmo.map(\.text) == [
                "Led incident response for the payments outage"
            ])
        #expect(!debrief.themes.isEmpty)
        #expect(!debrief.signals.isEmpty)
        #expect(!debrief.drills.isEmpty)
    }

    @Test("[DEBRIEF-5] generating a debrief for a Stage without attached notes is refused")
    func missingNotesIsRefused() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let profileStore = try makeProfileStore(container: container)
        let service = FixtureIntelligenceService.debriefFixture()
        let store = makeDebriefStore(
            container: container, profileStore: profileStore, service: service)

        let bare = try makeStage(in: container, notesOverview: nil)
        await store.generate(for: bare, generatedAt: Date(timeIntervalSince1970: 1_772_100_000))
        #expect(store.phase == .failed(.notesRequired))

        // A whitespace-only notes overview counts as no notes.
        let blank = try makeStage(in: container, notesOverview: "  \n\t ")
        await store.generate(for: blank, generatedAt: Date(timeIntervalSince1970: 1_772_100_000))
        #expect(store.phase == .failed(.notesRequired))

        #expect(await service.recordedRequests.isEmpty, "refused before any service call")
        #expect(bare.debrief == nil)
        #expect(blank.debrief == nil)
    }

    @Test("[DEBRIEF-6] generating a debrief with no API key stored is refused")
    func noAPIKeyIsRefused() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let profileStore = try makeProfileStore(container: container)
        let service = FixtureIntelligenceService.debriefFixture()
        let store = makeDebriefStore(
            container: container, profileStore: profileStore, service: service,
            keyStore: InMemoryAPIKeyStore(key: nil))
        let stage = try makeStage(in: container)

        await store.generate(for: stage, generatedAt: Date(timeIntervalSince1970: 1_772_100_000))

        #expect(store.phase == .failed(.apiKeyRequired))
        #expect(stage.debrief == nil)
        #expect(await service.recordedRequests.isEmpty, "refused before any service call")
    }

    @Test("[DEBRIEF-7] the debrief request contains the versioned debrief prompt")
    func debriefRequestCarriesTheBundledPrompt() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let profileStore = try makeProfileStore(container: container)
        let service = FixtureIntelligenceService.debriefFixture()
        let store = makeDebriefStore(
            container: container, profileStore: profileStore, service: service)
        let stage = try makeStage(in: container)

        await store.generate(for: stage, generatedAt: Date(timeIntervalSince1970: 1_772_100_000))

        let promptURL = try #require(
            Bundle.main.url(forResource: "debrief", withExtension: "md", subdirectory: "Prompts"),
            "Prompts/debrief.md missing from the app bundle"
        )
        let promptOnDisk = try String(contentsOf: promptURL, encoding: .utf8)
        let requests = await service.recordedRequests
        #expect(requests.count == 1)
        #expect(requests.first?.prompt == promptOnDisk, "the prompt is the file's content, never an inline string")
        let payload = try #require(requests.first?.payload)
        #expect(payload.contains("Interviewer asked twice about Kubernetes experience"), "the notes overview travels")
        #expect(payload.contains("technical"), "the Stage's kind travels")
        #expect(payload.contains("Expect systems questions."), "the prep context travels")
        #expect(payload.contains("Summit Labs"))
        #expect(payload.contains("Own platform reliability."))
        #expect(payload.contains("Led incident response for the payments outage"))
        #expect(payload.contains("\"index\" : 2"), "achievements carry their payload indices (decisions/0001)")
    }

    @Test("[DEBRIEF-8] the debrief lists each question the service reported with its answer quality")
    func questionsCarryTheirAnswerQuality() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let profileStore = try makeProfileStore(container: container)
        let store = makeDebriefStore(
            container: container, profileStore: profileStore,
            service: FixtureIntelligenceService.debriefFixture())
        let stage = try makeStage(in: container)

        await store.generate(for: stage, generatedAt: Date(timeIntervalSince1970: 1_772_100_000))

        let debrief = try #require(stage.debrief)
        let questions = debrief.orderedQuestions
        #expect(questions.map(\.question) == [
            "How did you handle the payments outage?",
            "How do you keep CI fast?",
        ], "questions keep the service's order")
        #expect(questions.map(\.quality) == [.adequate, .strong], "quality is categorical, never a number")
        #expect(questions.map(\.answerSummary) == [
            "Walked through the incident timeline but never mentioned leading the response",
            "Described the build-time work with concrete numbers",
        ])
    }

    @Test("[DEBRIEF-9] every debrief claim quotes the notes text it is grounded in")
    func everyClaimCarriesAGroundingQuote() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let profileStore = try makeProfileStore(container: container)
        let store = makeDebriefStore(
            container: container, profileStore: profileStore,
            service: FixtureIntelligenceService.debriefFixture())
        let stage = try makeStage(in: container)

        await store.generate(for: stage, generatedAt: Date(timeIntervalSince1970: 1_772_100_000))

        let debrief = try #require(stage.debrief)
        let claims: [(String, String)] =
            debrief.orderedQuestions.map { ($0.question, $0.quote) }
            + debrief.themes.map { ($0.text, $0.quote) }
            + debrief.signals.map { ($0.text, $0.quote) }
        try #require(!claims.isEmpty)
        for (claim, quote) in claims {
            #expect(!quote.isEmpty, "claim \"\(claim)\" carries a quote")
            #expect(
                Self.notesOverview.contains(quote),
                "the quote for \"\(claim)\" is a verbatim excerpt of the notes overview")
        }
    }

    /// The valid fixture bytes, for invalid-then-valid repair sequences.
    private var validJSON: Data {
        get throws {
            try Data(contentsOf: #require(
                Bundle.main.url(forResource: "debrief-result", withExtension: "json", subdirectory: "Fixtures"),
                "debrief-result.json missing from the bundled Fixtures folder"
            ))
        }
    }

    /// A schema-valid response whose theme quote appears nowhere in the notes.
    private var fabricatedQuoteResponse: Data {
        Data("""
        {
          "questions": [],
          "themes": [{"text": "Sounded very positive", "quote": "This sentence appears nowhere in the notes"}],
          "signals": [],
          "drills": []
        }
        """.utf8)
    }

    @Test("[DEBRIEF-10] a claim whose quote is absent from the notes overview fails validation")
    func fabricatedQuoteFailsValidation() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let profileStore = try makeProfileStore(container: container)
        let service = FixtureIntelligenceService(returning: [fabricatedQuoteResponse, try validJSON])
        let store = makeDebriefStore(
            container: container, profileStore: profileStore, service: service)
        let stage = try makeStage(in: container)

        await store.generate(for: stage, generatedAt: Date(timeIntervalSince1970: 1_772_100_000))

        // The fabricated quote fed the repair path and the valid repair
        // produced the debrief.
        #expect(store.phase == .generated)
        let requests = await service.recordedRequests
        #expect(requests.count == 2, "an ungrounded claim is handled exactly like a schema mismatch")
        let repair = try #require(requests.last)
        #expect(repair.payload.contains("Quotes not found in the notes overview"))
        #expect(repair.payload.contains("This sentence appears nowhere in the notes"))
    }

    @Test("[DEBRIEF-11] a question entry's missed ammo resolves to Achievements on the Profile")
    func missedAmmoResolvesToProfileAchievements() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let profileStore = try makeProfileStore(container: container)
        let store = makeDebriefStore(
            container: container, profileStore: profileStore,
            service: FixtureIntelligenceService.debriefFixture())
        let stage = try makeStage(in: container)

        await store.generate(for: stage, generatedAt: Date(timeIntervalSince1970: 1_772_100_000))

        let debrief = try #require(stage.debrief)
        let outage = try #require(
            profileStore.profile?.roles.first?.orderedAchievements.last,
            "payload index 2 is the outage achievement")
        let linked = try #require(debrief.orderedQuestions.first?.missedAmmo.first)
        #expect(
            linked.persistentModelID == outage.persistentModelID,
            "a relationship to the canon, never a copy")

        // The link survives rewording — the whole point of decisions/0001.
        try profileStore.updateAchievementText(outage, to: "Commanded the payments-outage incident response")
        let fresh = ModelContext(container)
        let refetched = try #require(try fresh.fetch(FetchDescriptor<Debrief>()).first)
        #expect(
            refetched.orderedQuestions.first?.missedAmmo.first?.text
                == "Commanded the payments-outage incident response")
    }

    @Test("[DEBRIEF-12] a missed-ammo reference matching no listed achievement fails validation")
    func outOfRangeMissedAmmoFailsValidation() async throws {
        // Index 7 matches nothing in a three-achievement payload; the fixture
        // returns the same invalid result to the repair request, so the run
        // ends failed.
        let outOfRange = Data("""
        {
          "questions": [
            {
              "question": "How did you handle the payments outage?",
              "answerSummary": "Walked the timeline",
              "quality": "adequate",
              "quote": "Walked through the incident timeline and on-call rotation",
              "missedAmmo": [7]
            }
          ],
          "themes": [],
          "signals": [],
          "drills": []
        }
        """.utf8)
        let container = try ProfileStore.container(inMemory: true)
        let profileStore = try makeProfileStore(container: container)
        let service = FixtureIntelligenceService(returning: outOfRange)
        let store = makeDebriefStore(
            container: container, profileStore: profileStore, service: service)
        let stage = try makeStage(in: container)

        await store.generate(for: stage, generatedAt: Date(timeIntervalSince1970: 1_772_100_000))

        #expect(store.phase == .failed(.resultInvalid))
        #expect(stage.debrief == nil, "invented history never reaches the store")
        let repair = try #require(await service.recordedRequests.last)
        #expect(repair.payload.contains("Missed-ammo indices not in the payload's achievement list"))
    }

    private var malformedResponse: Data {
        Data(#"{"questions": "not an array"}"#.utf8)
    }

    @Test("[DEBRIEF-13] a response failing validation triggers exactly one repair request")
    func validationFailureTriggersOneRepairRequest() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let profileStore = try makeProfileStore(container: container)
        let service = FixtureIntelligenceService(returning: [malformedResponse, try validJSON])
        let store = makeDebriefStore(
            container: container, profileStore: profileStore, service: service)
        let stage = try makeStage(in: container)

        await store.generate(for: stage, generatedAt: Date(timeIntervalSince1970: 1_772_100_000))

        #expect(store.phase == .generated)
        #expect(stage.debrief != nil, "a valid repair response produces the debrief as normal")

        let requests = await service.recordedRequests
        #expect(requests.count == 2, "an invalid-then-valid sequence records two requests, never three")
        let repair = try #require(requests.last)
        #expect(repair.prompt == requests.first?.prompt, "the repair keeps the versioned prompt")
        // The original request content, the invalid response, and the failure.
        #expect(repair.payload.contains("failed validation"))
        #expect(repair.payload.contains(#""questions": "not an array""#))
        #expect(repair.payload.contains("Interviewer asked twice about Kubernetes experience"))
    }

    @Test("[DEBRIEF-14] a repair response failing validation fails the run")
    func repairFailureFailsTheRun() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let profileStore = try makeProfileStore(container: container)
        let service = FixtureIntelligenceService(returning: [malformedResponse, malformedResponse])
        let store = makeDebriefStore(
            container: container, profileStore: profileStore, service: service)
        let stage = try makeStage(in: container)

        await store.generate(for: stage, generatedAt: Date(timeIntervalSince1970: 1_772_100_000))

        #expect(store.phase == .failed(.resultInvalid))
        #expect(stage.debrief == nil, "nothing is written")
        #expect(try ModelContext(container).fetch(FetchDescriptor<Debrief>()).isEmpty)
        #expect(await service.recordedRequests.count == 2, "no further request is sent after the repair fails")
    }

    @Test("[DEBRIEF-14] a failed run leaves an existing debrief exactly as it was")
    func failedRunLeavesExistingDebriefUntouched() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let profileStore = try makeProfileStore(container: container)
        let stage = try makeStage(in: container)

        let first = makeDebriefStore(
            container: container, profileStore: profileStore,
            service: FixtureIntelligenceService.debriefFixture())
        await first.generate(for: stage, generatedAt: Date(timeIntervalSince1970: 1_772_100_000))
        let existing = try #require(stage.debrief)

        let failing = makeDebriefStore(
            container: container, profileStore: profileStore,
            service: FixtureIntelligenceService(returning: [malformedResponse, malformedResponse]))
        await failing.generate(for: stage, generatedAt: Date(timeIntervalSince1970: 1_772_200_000))

        #expect(failing.phase == .failed(.resultInvalid))
        let kept = try #require(stage.debrief, "replacement happens only on a valid result")
        #expect(kept === existing)
        #expect(kept.generatedAt == Date(timeIntervalSince1970: 1_772_100_000))
        #expect(try ModelContext(container).fetch(FetchDescriptor<Debrief>()).count == 1)
    }

    @Test("[DEBRIEF-15] generating a debrief for a Stage that already has one replaces the existing debrief")
    func regeneratingReplacesTheExistingDebrief() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let profileStore = try makeProfileStore(container: container)
        let store = makeDebriefStore(
            container: container, profileStore: profileStore,
            service: FixtureIntelligenceService.debriefFixture())
        let stage = try makeStage(in: container)

        await store.generate(for: stage, generatedAt: Date(timeIntervalSince1970: 1_772_100_000))
        let first = try #require(stage.debrief)
        await store.generate(for: stage, generatedAt: Date(timeIntervalSince1970: 1_772_200_000))
        let second = try #require(stage.debrief)

        #expect(first !== second)
        #expect(second.generatedAt == Date(timeIntervalSince1970: 1_772_200_000))
        let context = ModelContext(container)
        #expect(
            try context.fetch(FetchDescriptor<Debrief>()).count == 1,
            "the old record is deleted, not orphaned")
        #expect(
            try context.fetch(FetchDescriptor<DebriefQuestion>()).count == 2,
            "the old question entries go with it")
    }

    @Test("[DEBRIEF-16] the debrief carries the service's themes, signals and drills verbatim")
    func themesSignalsAndDrillsAreCarriedVerbatim() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let profileStore = try makeProfileStore(container: container)
        let store = makeDebriefStore(
            container: container, profileStore: profileStore,
            service: FixtureIntelligenceService.debriefFixture())
        let stage = try makeStage(in: container)

        await store.generate(for: stage, generatedAt: Date(timeIntervalSince1970: 1_772_100_000))

        let debrief = try #require(stage.debrief)
        #expect(debrief.themes == [
            GroundedRemark(
                text: "Reliability ran through the whole conversation",
                quote: "Walked through the incident timeline and on-call rotation")
        ])
        #expect(debrief.signals == [
            GroundedRemark(
                text: "The interviewer probed Kubernetes depth twice",
                quote: "Interviewer asked twice about Kubernetes experience")
        ])
        #expect(debrief.drills == [
            "Rehearse the payments outage story leading with the incident-command role"
        ])
    }

    @Test("[DEBRIEF-17] a debrief result wrapped in a markdown code fence produces a debrief")
    func fencedResultProducesDebrief() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let profileStore = try makeProfileStore(container: container)
        let fenced = Data("```json\n\(String(decoding: try validJSON, as: UTF8.self))\n```".utf8)
        let service = FixtureIntelligenceService(returning: fenced)
        let store = makeDebriefStore(
            container: container, profileStore: profileStore, service: service)
        let stage = try makeStage(in: container)

        await store.generate(for: stage, generatedAt: Date(timeIntervalSince1970: 1_772_100_000))

        #expect(store.phase == .generated)
        let debrief = try #require(stage.debrief)
        #expect(debrief.orderedQuestions.count == 2, "the fenced result reads exactly as the bare one")
        // The fence never costs the single repair request.
        #expect(await service.recordedRequests.count == 1)
    }
}

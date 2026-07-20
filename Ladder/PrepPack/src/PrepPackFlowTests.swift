import Foundation
import SwiftData
import Testing

@testable import Ladder

/// The canned prep result loads from the app bundle's Fixtures folder
/// (tests run in the app host). No network anywhere.
@MainActor
struct PrepPackFlowTests {
    /// One role, three achievements — payload indices 0, 1, 2 in sort order.
    /// The bundled prep-result fixture's talking point references index 2.
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

    /// An active Application with one technical Stage — the JD alone is
    /// enough input to prep from ([PREP-5]).
    private func makeStage(
        in container: ModelContainer,
        kind: StageKind = .technical,
        jobDescription: String = "Own platform reliability.",
        prepContext: String = "Expect systems questions.",
        sortIndex: Int = 0
    ) throws -> Stage {
        let context = ModelContext(container)
        let application = Application(
            company: "Summit Labs", roleTitle: "Platform Engineer",
            jobDescription: jobDescription, status: .active)
        context.insert(application)
        let stage = Stage(kind: kind, prepContext: prepContext, sortIndex: sortIndex)
        context.insert(stage)
        stage.application = application
        try context.save()
        return stage
    }

    private func makePrepPackStore(
        container: ModelContainer,
        profileStore: ProfileStore,
        service: FixtureIntelligenceService,
        keyStore: any APIKeyStore = InMemoryAPIKeyStore(key: "sk-test")
    ) -> PrepPackStore {
        PrepPackStore(
            container: container,
            profileStore: profileStore,
            keyStore: keyStore,
            makeIntelligence: { _ in service }
        )
    }

    @Test("[PREP-1] a generated prep pack is still on the Stage after the app relaunches")
    func generatedPrepPackSurvivesRelaunch() async throws {
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }

        do {
            let container = try ProfileStore.container(at: url)
            let profileStore = try makeProfileStore(container: container)
            let stage = try makeStage(in: container)
            let store = makePrepPackStore(
                container: container,
                profileStore: profileStore,
                service: FixtureIntelligenceService.prepFixture()
            )

            await store.generate(
                for: stage, generatedAt: Date(timeIntervalSince1970: 1_772_300_000))

            #expect(store.phase == .generated)
        }

        let reopened = try ProfileStore.container(at: url)
        let context = ModelContext(reopened)
        let stage = try #require(try context.fetch(FetchDescriptor<Stage>()).first)
        let pack = try #require(stage.prepPack, "the prep pack is still on the Stage")
        #expect(pack.generatedAt == Date(timeIntervalSince1970: 1_772_300_000))
        #expect(pack.likelyQuestions == [
            "Walk me through a production incident you owned end to end.",
            "How would you scale our ingestion pipeline?",
        ])
        let points = pack.orderedTalkingPoints
        #expect(points.count == 2)
        #expect(points.first?.text == "Lead with the payments-outage incident command story")
        #expect(
            points.first?.achievements.map(\.text) == [
                "Led incident response for the payments outage"
            ])
        #expect(pack.companyBrief?.isEmpty == false)
        #expect(pack.mockTasks.count == 1)
    }

    /// Attaches a debrief to a Stage — the marker travels as the question
    /// text so payload assertions can tell debriefs apart.
    private func attachDebrief(
        to stage: Stage,
        question: String,
        answerSummary: String = "Walked the timeline",
        quality: AnswerQuality = .adequate,
        theme: String? = nil,
        drill: String? = nil,
        in context: ModelContext
    ) throws {
        let debrief = Debrief(
            generatedAt: Date(timeIntervalSince1970: 1_772_100_000),
            themes: theme.map { [GroundedRemark(text: $0, quote: "q")] } ?? [],
            signals: [],
            drills: drill.map { [$0] } ?? [])
        context.insert(debrief)
        let entry = DebriefQuestion(
            question: question, answerSummary: answerSummary, quality: quality,
            quote: "q", sortIndex: 0)
        context.insert(entry)
        entry.debrief = debrief
        stage.debrief = debrief
        try context.save()
    }

    /// The valid fixture bytes, for invalid-then-valid repair sequences.
    private var validJSON: Data {
        get throws {
            try Data(contentsOf: #require(
                Bundle.main.url(forResource: "prep-result", withExtension: "json", subdirectory: "Fixtures"),
                "prep-result.json missing from the bundled Fixtures folder"
            ))
        }
    }

    private var malformedResponse: Data {
        Data(#"{"likelyQuestions": "not an array"}"#.utf8)
    }

    /// Schema-valid, no mock tasks — what a non-technical stage should get.
    private var noMockTasksResponse: Data {
        Data("""
        {
          "likelyQuestions": ["What would your first 90 days look like?"],
          "talkingPoints": [],
          "companyBrief": "Summit Labs is hiring a Platform Engineer.",
          "mockTasks": []
        }
        """.utf8)
    }

    @Test("[PREP-5] generating a prep pack with no job description, no prep context and no prior debriefs is refused")
    func allInputsEmptyIsRefused() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let profileStore = try makeProfileStore(container: container)
        let service = FixtureIntelligenceService.prepFixture()
        let store = makePrepPackStore(
            container: container, profileStore: profileStore, service: service)

        let bare = try makeStage(in: container, jobDescription: "", prepContext: "")
        await store.generate(for: bare, generatedAt: Date(timeIntervalSince1970: 1_772_300_000))
        #expect(store.phase == .failed(.inputsRequired))

        // Whitespace-only inputs count as absent.
        let blank = try makeStage(in: container, jobDescription: " \n\t ", prepContext: "  ")
        await store.generate(for: blank, generatedAt: Date(timeIntervalSince1970: 1_772_300_000))
        #expect(store.phase == .failed(.inputsRequired))

        #expect(await service.recordedRequests.isEmpty, "refused before any service call")
        #expect(bare.prepPack == nil)
        #expect(blank.prepPack == nil)

        // A later-stage pack riding on prior debriefs alone generates: only
        // all-three-empty refuses.
        let ridden = try makeStage(
            in: container, jobDescription: "", prepContext: "", sortIndex: 1)
        let context = try #require(ridden.modelContext)
        let earlier = Stage(kind: .screen, sortIndex: 0)
        context.insert(earlier)
        earlier.application = ridden.application
        try attachDebrief(
            to: earlier, question: "How did you handle the payments outage?", in: context)
        await store.generate(for: ridden, generatedAt: Date(timeIntervalSince1970: 1_772_300_000))
        #expect(store.phase == .generated)
        #expect(ridden.prepPack != nil)
    }

    @Test("[PREP-6] generating a prep pack with no API key stored is refused")
    func noAPIKeyIsRefused() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let profileStore = try makeProfileStore(container: container)
        let service = FixtureIntelligenceService.prepFixture()
        let store = makePrepPackStore(
            container: container, profileStore: profileStore, service: service,
            keyStore: InMemoryAPIKeyStore(key: nil))
        let stage = try makeStage(in: container)

        await store.generate(for: stage, generatedAt: Date(timeIntervalSince1970: 1_772_300_000))

        #expect(store.phase == .failed(.apiKeyRequired))
        #expect(stage.prepPack == nil)
        #expect(await service.recordedRequests.isEmpty, "refused before any service call")
    }

    @Test("[PREP-7] the prep request contains the versioned prep prompt")
    func prepRequestCarriesTheBundledPrompt() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let profileStore = try makeProfileStore(container: container)
        let service = FixtureIntelligenceService.prepFixture()
        let store = makePrepPackStore(
            container: container, profileStore: profileStore, service: service)
        let stage = try makeStage(in: container, sortIndex: 1)
        let context = try #require(stage.modelContext)
        let earlier = Stage(kind: .screen, sortIndex: 0)
        context.insert(earlier)
        earlier.application = stage.application
        try attachDebrief(
            to: earlier,
            question: "How did you handle the payments outage?",
            theme: "Reliability ran through the whole conversation",
            drill: "Rehearse the outage story leading with the incident-command role",
            in: context)

        await store.generate(for: stage, generatedAt: Date(timeIntervalSince1970: 1_772_300_000))

        let promptURL = try #require(
            Bundle.main.url(forResource: "prep", withExtension: "md", subdirectory: "Prompts"),
            "Prompts/prep.md missing from the app bundle"
        )
        let promptOnDisk = try String(contentsOf: promptURL, encoding: .utf8)
        let requests = await service.recordedRequests
        #expect(requests.count == 1)
        #expect(requests.first?.prompt == promptOnDisk, "the prompt is the file's content, never an inline string")
        let payload = try #require(requests.first?.payload)
        #expect(payload.contains("technical"), "the Stage's kind travels")
        #expect(payload.contains("Expect systems questions."), "the prep context travels")
        #expect(payload.contains("\"mockTasksWanted\" : true"), "the technical-kind gate travels")
        #expect(payload.contains("Summit Labs"))
        #expect(payload.contains("Platform Engineer"))
        #expect(payload.contains("Own platform reliability."))
        #expect(payload.contains("How did you handle the payments outage?"), "the prior debrief's questions travel")
        #expect(payload.contains("adequate"), "the prior answer quality travels")
        #expect(payload.contains("Reliability ran through the whole conversation"), "the prior themes travel")
        #expect(payload.contains("Rehearse the outage story leading with the incident-command role"), "the prior drills travel")
        #expect(payload.contains("Led incident response for the payments outage"))
        #expect(payload.contains("\"index\" : 2"), "achievements carry their payload indices (decisions/0001)")
    }

    @Test("[PREP-8] the prep payload's debriefs come only from Stages ordered before the prepped Stage")
    func priorDebriefsAreStrictlyEarlierByStageOrder() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let profileStore = try makeProfileStore(container: container)
        let service = FixtureIntelligenceService.prepFixture()
        let store = makePrepPackStore(
            container: container, profileStore: profileStore, service: service)

        let context = ModelContext(container)
        let application = Application(
            company: "Summit Labs", roleTitle: "Platform Engineer",
            jobDescription: "Own platform reliability.", status: .active)
        context.insert(application)
        let first = Stage(kind: .screen, sortIndex: 0)
        let second = Stage(kind: .recruiter, sortIndex: 1)
        let prepped = Stage(kind: .technical, sortIndex: 2)
        let later = Stage(kind: .final, sortIndex: 3)
        for stage in [first, second, prepped, later] {
            context.insert(stage)
            stage.application = application
        }
        try context.save()
        try attachDebrief(to: first, question: "FIRST-SCREEN-MARKER", in: context)
        try attachDebrief(to: second, question: "RECRUITER-MARKER", in: context)
        try attachDebrief(to: prepped, question: "OWN-STAGE-MARKER", in: context)
        try attachDebrief(to: later, question: "LATER-STAGE-MARKER", in: context)

        await store.generate(for: prepped, generatedAt: Date(timeIntervalSince1970: 1_772_300_000))

        let payload = try #require(await service.recordedRequests.first?.payload)
        let firstRange = try #require(
            payload.range(of: "FIRST-SCREEN-MARKER"), "the earlier debriefs enter the payload")
        let secondRange = try #require(payload.range(of: "RECRUITER-MARKER"))
        #expect(
            firstRange.lowerBound < secondRange.lowerBound,
            "included debriefs follow stage order")
        #expect(!payload.contains("OWN-STAGE-MARKER"), "the prepped stage's own debrief is never prior")
        #expect(!payload.contains("LATER-STAGE-MARKER"), "a later stage's debrief is never prior")
    }

    @Test("[PREP-9] the prep pack lists the service's likely questions in the service's order")
    func likelyQuestionsKeepTheServicesOrder() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let profileStore = try makeProfileStore(container: container)
        let store = makePrepPackStore(
            container: container, profileStore: profileStore,
            service: FixtureIntelligenceService.prepFixture())
        let stage = try makeStage(in: container)

        await store.generate(for: stage, generatedAt: Date(timeIntervalSince1970: 1_772_300_000))

        let pack = try #require(stage.prepPack)
        #expect(pack.likelyQuestions == [
            "Walk me through a production incident you owned end to end.",
            "How would you scale our ingestion pipeline?",
        ], "persisted verbatim, in the service's order, never reworded")
    }

    @Test("[PREP-10] a talking point's mapped achievements resolve to Achievements on the Profile")
    func mappedAchievementsResolveToProfileAchievements() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let profileStore = try makeProfileStore(container: container)
        let store = makePrepPackStore(
            container: container, profileStore: profileStore,
            service: FixtureIntelligenceService.prepFixture())
        let stage = try makeStage(in: container)

        await store.generate(for: stage, generatedAt: Date(timeIntervalSince1970: 1_772_300_000))

        let pack = try #require(stage.prepPack)
        let outage = try #require(
            profileStore.profile?.roles.first?.orderedAchievements.last,
            "payload index 2 is the outage achievement")
        let linked = try #require(pack.orderedTalkingPoints.first?.achievements.first)
        #expect(
            linked.persistentModelID == outage.persistentModelID,
            "a relationship to the canon, never a copy")
        #expect(
            pack.orderedTalkingPoints.last?.achievements.isEmpty == true,
            "a point with no mapped achievements is valid")

        // The link survives rewording — the whole point of decisions/0001.
        try profileStore.updateAchievementText(outage, to: "Commanded the payments-outage incident response")
        let fresh = ModelContext(container)
        let refetched = try #require(try fresh.fetch(FetchDescriptor<PrepPack>()).first)
        #expect(
            refetched.orderedTalkingPoints.first?.achievements.first?.text
                == "Commanded the payments-outage incident response")
    }

    @Test("[PREP-11] an achievement reference matching no listed achievement fails validation")
    func outOfRangeAchievementReferenceFailsValidation() async throws {
        // Index 7 matches nothing in a three-achievement payload; the fixture
        // returns the same invalid result to the repair request, so the run
        // ends failed.
        let outOfRange = Data("""
        {
          "likelyQuestions": ["Walk me through a production incident."],
          "talkingPoints": [
            {"text": "Lead with the outage story", "achievements": [7]}
          ],
          "companyBrief": "Summit Labs is hiring.",
          "mockTasks": []
        }
        """.utf8)
        let container = try ProfileStore.container(inMemory: true)
        let profileStore = try makeProfileStore(container: container)
        let service = FixtureIntelligenceService(returning: outOfRange)
        let store = makePrepPackStore(
            container: container, profileStore: profileStore, service: service)
        let stage = try makeStage(in: container)

        await store.generate(for: stage, generatedAt: Date(timeIntervalSince1970: 1_772_300_000))

        #expect(store.phase == .failed(.resultInvalid))
        #expect(stage.prepPack == nil, "invented history never reaches the store")
        let repair = try #require(await service.recordedRequests.last)
        #expect(repair.payload.contains("Achievement indices not in the payload's achievement list"))
    }

    @Test("[PREP-12] a technical-type Stage's prep pack carries the service's mock tasks")
    func technicalStagePackCarriesMockTasks() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let profileStore = try makeProfileStore(container: container)
        let store = makePrepPackStore(
            container: container, profileStore: profileStore,
            service: FixtureIntelligenceService.prepFixture())
        let stage = try makeStage(in: container, kind: .takeHome)

        await store.generate(for: stage, generatedAt: Date(timeIntervalSince1970: 1_772_300_000))

        #expect(store.phase == .generated)
        let pack = try #require(stage.prepPack)
        #expect(pack.mockTasks == [
            MockTask(
                title: "Design a rate limiter",
                brief: "Sketch a rate limiter for a multi-tenant API: cover burst handling, fairness between tenants, and what you would measure in production.")
        ], "mock tasks are persisted verbatim in the service's order")
    }

    @Test("[PREP-13] a result carrying mock tasks for a non-technical Stage fails validation")
    func mockTasksForNonTechnicalStageFailValidation() async throws {
        // The fixture result carries mock tasks; for a behavioral stage that
        // is a schema violation, repaired away by the mock-task-free repair
        // response — never silently dropped.
        let container = try ProfileStore.container(inMemory: true)
        let profileStore = try makeProfileStore(container: container)
        let service = FixtureIntelligenceService(
            returning: [try validJSON, noMockTasksResponse])
        let store = makePrepPackStore(
            container: container, profileStore: profileStore, service: service)
        let stage = try makeStage(in: container, kind: .behavioral)

        await store.generate(for: stage, generatedAt: Date(timeIntervalSince1970: 1_772_300_000))

        #expect(store.phase == .generated)
        let requests = await service.recordedRequests
        #expect(requests.count == 2, "the unwanted mock tasks fed the repair path")
        let repair = try #require(requests.last)
        #expect(repair.payload.contains("not"), "the failure names the gate")
        #expect(repair.payload.contains("technical-type"))
        let pack = try #require(stage.prepPack)
        #expect(pack.mockTasks.isEmpty, "the repaired pack carries no mock tasks")
    }

    @Test("[PREP-14] the prep pack carries the service's company brief verbatim")
    func companyBriefIsCarriedVerbatim() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let profileStore = try makeProfileStore(container: container)
        let store = makePrepPackStore(
            container: container, profileStore: profileStore,
            service: FixtureIntelligenceService.prepFixture())
        let stage = try makeStage(in: container)

        await store.generate(for: stage, generatedAt: Date(timeIntervalSince1970: 1_772_300_000))

        let pack = try #require(stage.prepPack)
        #expect(
            pack.companyBrief
                == "Summit Labs is hiring a Platform Engineer to own reliability end to end; the JD centres on incident response and infrastructure ownership.",
            "persisted as returned, never re-derived")

        // A result with no company brief is valid when there is nothing to
        // say.
        let noBrief = Data("""
        {
          "likelyQuestions": ["What would your first 90 days look like?"],
          "talkingPoints": [],
          "mockTasks": []
        }
        """.utf8)
        let briefless = makePrepPackStore(
            container: container, profileStore: profileStore,
            service: FixtureIntelligenceService(returning: noBrief))
        let plain = try makeStage(in: container, kind: .behavioral)
        await briefless.generate(for: plain, generatedAt: Date(timeIntervalSince1970: 1_772_300_000))
        #expect(briefless.phase == .generated)
        #expect(try #require(plain.prepPack).companyBrief == nil)
    }

    @Test("[PREP-15] a response failing validation triggers exactly one repair request")
    func validationFailureTriggersOneRepairRequest() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let profileStore = try makeProfileStore(container: container)
        let service = FixtureIntelligenceService(returning: [malformedResponse, try validJSON])
        let store = makePrepPackStore(
            container: container, profileStore: profileStore, service: service)
        let stage = try makeStage(in: container)

        await store.generate(for: stage, generatedAt: Date(timeIntervalSince1970: 1_772_300_000))

        #expect(store.phase == .generated)
        #expect(stage.prepPack != nil, "a valid repair response produces the prep pack as normal")

        let requests = await service.recordedRequests
        #expect(requests.count == 2, "an invalid-then-valid sequence records two requests, never three")
        let repair = try #require(requests.last)
        #expect(repair.prompt == requests.first?.prompt, "the repair keeps the versioned prompt")
        // The original request content, the invalid response, and the failure.
        #expect(repair.payload.contains("failed validation"))
        #expect(repair.payload.contains(#""likelyQuestions": "not an array""#))
        #expect(repair.payload.contains("Own platform reliability."))
    }

    @Test("[PREP-16] a repair response failing validation fails the run")
    func repairFailureFailsTheRun() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let profileStore = try makeProfileStore(container: container)
        let service = FixtureIntelligenceService(returning: [malformedResponse, malformedResponse])
        let store = makePrepPackStore(
            container: container, profileStore: profileStore, service: service)
        let stage = try makeStage(in: container)

        await store.generate(for: stage, generatedAt: Date(timeIntervalSince1970: 1_772_300_000))

        #expect(store.phase == .failed(.resultInvalid))
        #expect(stage.prepPack == nil, "nothing is written")
        #expect(try ModelContext(container).fetch(FetchDescriptor<PrepPack>()).isEmpty)
        #expect(await service.recordedRequests.count == 2, "no further request is sent after the repair fails")
    }

    @Test("[PREP-16] a failed run leaves an existing prep pack exactly as it was")
    func failedRunLeavesExistingPackUntouched() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let profileStore = try makeProfileStore(container: container)
        let stage = try makeStage(in: container)

        let first = makePrepPackStore(
            container: container, profileStore: profileStore,
            service: FixtureIntelligenceService.prepFixture())
        await first.generate(for: stage, generatedAt: Date(timeIntervalSince1970: 1_772_300_000))
        let existing = try #require(stage.prepPack)

        let failing = makePrepPackStore(
            container: container, profileStore: profileStore,
            service: FixtureIntelligenceService(returning: [malformedResponse, malformedResponse]))
        await failing.generate(for: stage, generatedAt: Date(timeIntervalSince1970: 1_772_400_000))

        #expect(failing.phase == .failed(.resultInvalid))
        let kept = try #require(stage.prepPack, "replacement happens only on a valid result")
        #expect(kept === existing)
        #expect(kept.generatedAt == Date(timeIntervalSince1970: 1_772_300_000))
        #expect(try ModelContext(container).fetch(FetchDescriptor<PrepPack>()).count == 1)
    }

    @Test("[PREP-17] generating a prep pack for a Stage that already has one replaces the existing pack")
    func regeneratingReplacesTheExistingPack() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let profileStore = try makeProfileStore(container: container)
        let store = makePrepPackStore(
            container: container, profileStore: profileStore,
            service: FixtureIntelligenceService.prepFixture())
        let stage = try makeStage(in: container)

        await store.generate(for: stage, generatedAt: Date(timeIntervalSince1970: 1_772_300_000))
        let first = try #require(stage.prepPack)
        await store.generate(for: stage, generatedAt: Date(timeIntervalSince1970: 1_772_400_000))
        let second = try #require(stage.prepPack)

        #expect(first !== second)
        #expect(second.generatedAt == Date(timeIntervalSince1970: 1_772_400_000))
        let context = ModelContext(container)
        #expect(
            try context.fetch(FetchDescriptor<PrepPack>()).count == 1,
            "the old record is deleted, not orphaned")
        #expect(
            try context.fetch(FetchDescriptor<PrepTalkingPoint>()).count == 2,
            "the old talking-point rows go with it")
    }

    @Test("[PREP-18] a prep result wrapped in a markdown code fence produces a prep pack")
    func fencedResultProducesPrepPack() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let profileStore = try makeProfileStore(container: container)
        let fenced = Data("```json\n\(String(decoding: try validJSON, as: UTF8.self))\n```".utf8)
        let service = FixtureIntelligenceService(returning: fenced)
        let store = makePrepPackStore(
            container: container, profileStore: profileStore, service: service)
        let stage = try makeStage(in: container)

        await store.generate(for: stage, generatedAt: Date(timeIntervalSince1970: 1_772_300_000))

        #expect(store.phase == .generated)
        let pack = try #require(stage.prepPack)
        #expect(pack.orderedTalkingPoints.count == 2, "the fenced result reads exactly as the bare one")
        // The fence never costs the single repair request.
        #expect(await service.recordedRequests.count == 1)
    }
}

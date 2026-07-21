import Foundation
import SwiftData
import Testing

@testable import Ladder

/// The canned tailor result loads from the app bundle's Fixtures folder
/// (tests run in the app host). No network anywhere.
@MainActor
struct TailorFlowTests {
    /// One role, three achievements — payload ids a1, a2, a3 in sort order.
    /// The bundled tailor-result fixture selects a1 and a3.
    private func makeProfileStore() throws -> ProfileStore {
        let store = try ProfileStore(container: ProfileStore.container(inMemory: true))
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

    private func makeTailorStore(
        profileStore: ProfileStore,
        service: FixtureIntelligenceService,
        keyStore: any APIKeyStore = InMemoryAPIKeyStore(key: "sk-test")
    ) -> TailorStore {
        TailorStore(
            profileStore: profileStore,
            keyStore: keyStore,
            makeIntelligence: { _ in service }
        )
    }

    private var jobDetails: JobDetails {
        JobDetails(
            company: "Summit Labs",
            roleTitle: "Platform Engineer",
            jobDescription: "Own platform reliability. Kubernetes, CI at scale, incident response."
        )
    }

    @Test("[TAILOR-1] running a tailor for a pasted job description produces a tailor result for review")
    func tailorRunProducesResultForReview() async throws {
        let profileStore = try makeProfileStore()
        let store = makeTailorStore(
            profileStore: profileStore,
            service: FixtureIntelligenceService.tailorFixture()
        )

        await store.startRun(jobDetails)

        #expect(store.phase == .review)
        let review = try #require(store.review)
        #expect(review.items.map(\.achievement.text) == [
            "Cut CI build times across every product target",
            "Led incident response for the payments outage",
        ])
        #expect(review.items.first?.bullet.contains("feedback loop") == true)
    }

    @Test("[TAILOR-2] a tailor run with an empty job description is refused")
    func emptyJobDescriptionIsRefused() async throws {
        let service = FixtureIntelligenceService.tailorFixture()
        let store = makeTailorStore(profileStore: try makeProfileStore(), service: service)

        // Whitespace-only counts as empty.
        var details = jobDetails
        details.jobDescription = "  \n\t "
        await store.startRun(details)

        #expect(store.phase == .failed(.jobDescriptionRequired))
        #expect(store.review == nil)
        #expect(await service.recordedRequests.isEmpty, "refused before any service call")
    }

    @Test("[TAILOR-3] starting a tailor run when the Profile has no achievements is refused")
    func noAchievementsIsRefused() async throws {
        let profileStore = try ProfileStore(container: ProfileStore.container(inMemory: true))
        try profileStore.load()
        try profileStore.createProfile(name: "Alex Climber", headline: "Staff Engineer")
        try profileStore.addRole(
            company: "Acme", title: "Senior Engineer",
            start: Date(timeIntervalSince1970: 1_600_000_000), end: nil
        )
        let service = FixtureIntelligenceService.tailorFixture()
        let store = makeTailorStore(profileStore: profileStore, service: service)

        await store.startRun(jobDetails)

        #expect(store.phase == .failed(.achievementsRequired))
        #expect(store.review == nil)
        #expect(await service.recordedRequests.isEmpty, "refused before any service call")
    }

    @Test("[TAILOR-4] starting a tailor run with no API key stored is refused")
    func noAPIKeyIsRefused() async throws {
        let service = FixtureIntelligenceService.tailorFixture()
        let store = makeTailorStore(
            profileStore: try makeProfileStore(),
            service: service,
            keyStore: InMemoryAPIKeyStore(key: nil)
        )

        await store.startRun(jobDetails)

        #expect(store.phase == .failed(.apiKeyRequired))
        #expect(store.review == nil)
        #expect(await service.recordedRequests.isEmpty, "refused before any service call")
    }

    @Test("[TAILOR-5] the tailor request contains the versioned tailor prompt")
    func tailorRequestCarriesTheBundledPrompt() async throws {
        let service = FixtureIntelligenceService.tailorFixture()
        let store = makeTailorStore(profileStore: try makeProfileStore(), service: service)

        await store.startRun(jobDetails)

        let promptURL = try #require(
            Bundle.main.url(forResource: "tailor", withExtension: "md", subdirectory: "Prompts"),
            "Prompts/tailor.md missing from the app bundle"
        )
        let promptOnDisk = try String(contentsOf: promptURL, encoding: .utf8)
        let requests = await service.recordedRequests
        #expect(requests.count == 1)
        #expect(requests.first?.prompt == promptOnDisk, "the prompt is the file's content, never an inline string")
        let payload = try #require(requests.first?.payload)
        #expect(payload.contains("Cut CI build times across every product target"))
        #expect(payload.contains("Own platform reliability. Kubernetes, CI at scale, incident response."))
        #expect(payload.contains("Summit Labs"))
    }

    @Test("[TAILOR-6] the tailor result lists each gap the service flagged")
    func gapsAreListedVerbatim() async throws {
        let store = makeTailorStore(
            profileStore: try makeProfileStore(),
            service: FixtureIntelligenceService.tailorFixture()
        )

        await store.startRun(jobDetails)

        let review = try #require(store.review)
        #expect(review.gaps == ["The JD asks for Kubernetes; nothing on file mentions it"])
    }

    @Test("[TAILOR-7] the tailor result carries the service's selection rationale")
    func rationaleIsCarriedVerbatim() async throws {
        let store = makeTailorStore(
            profileStore: try makeProfileStore(),
            service: FixtureIntelligenceService.tailorFixture()
        )

        await store.startRun(jobDetails)

        let review = try #require(store.review)
        #expect(review.rationale == "CI and incident-response work map directly to the JD's platform-reliability focus; the sync engine achievement is a weaker fit.")
    }

    @Test("[TAILOR-8] a tailor result selecting an achievement not on the Profile fails validation")
    func unknownAchievementFailsValidation() async throws {
        // "a9" matches nothing in the payload's id map; the fixture returns
        // the same invalid result to the repair request, so the run ends failed.
        let unknownSelection = Data("""
        {
          "summary": "…",
          "selections": [{"achievementID": "a9", "bullet": "Invented history"}],
          "gaps": [],
          "rationale": "…"
        }
        """.utf8)
        let profileStore = try makeProfileStore()
        let store = makeTailorStore(
            profileStore: profileStore,
            service: FixtureIntelligenceService(returning: unknownSelection)
        )

        await store.startRun(jobDetails)

        #expect(store.phase == .failed(.resultInvalid))
        #expect(store.review == nil, "no review is offered")
    }

    private var malformedResponse: Data {
        Data(#"{"selections": "not an array"}"#.utf8)
    }

    @Test("[TAILOR-9] a response failing validation triggers exactly one repair request")
    func validationFailureTriggersOneRepairRequest() async throws {
        let fixtureURL = try #require(
            Bundle.main.url(forResource: "tailor-result", withExtension: "json", subdirectory: "Fixtures")
        )
        let validJSON = try Data(contentsOf: fixtureURL)
        let service = FixtureIntelligenceService(returning: [malformedResponse, validJSON])
        let store = makeTailorStore(profileStore: try makeProfileStore(), service: service)

        await store.startRun(jobDetails)

        #expect(store.phase == .review)
        #expect(store.review != nil)

        let requests = await service.recordedRequests
        #expect(requests.count == 2, "an invalid-then-valid sequence records two requests, never three")
        let repair = try #require(requests.last)
        #expect(repair.prompt == requests.first?.prompt, "the repair keeps the versioned prompt")
        // The original request content, the invalid response, and the failure.
        #expect(repair.payload.contains("failed validation"))
        #expect(repair.payload.contains(#""selections": "not an array""#))
        #expect(repair.payload.contains("Cut CI build times across every product target"))
    }

    @Test("[TAILOR-10] a repair response failing validation fails the run")
    func repairFailureFailsTheRun() async throws {
        let service = FixtureIntelligenceService(returning: [malformedResponse, malformedResponse])
        let store = makeTailorStore(profileStore: try makeProfileStore(), service: service)

        await store.startRun(jobDetails)

        #expect(store.phase == .failed(.resultInvalid))
        #expect(store.review == nil, "no review is offered")
        #expect(await service.recordedRequests.count == 2, "no further request is sent after the repair fails")
    }

    @Test("[TAILOR-11] the review shows each expanded bullet beside its achievement's canonical text")
    func reviewPairsCanonicalTextWithBullet() async throws {
        let store = makeTailorStore(
            profileStore: try makeProfileStore(),
            service: FixtureIntelligenceService.tailorFixture()
        )

        await store.startRun(jobDetails)

        let review = try #require(store.review)
        let pairs = review.items.map { ($0.achievement.text, $0.bullet) }
        try #require(pairs.count == 2)
        #expect(pairs[0].0 == "Cut CI build times across every product target")
        #expect(pairs[0].1 == "Drove CI build times down across every product target, tightening the platform feedback loop")
        #expect(pairs[1].0 == "Led incident response for the payments outage")
        #expect(pairs[1].1 == "Led cross-team incident response for a critical payments outage")
    }

    @Test("[TAILOR-12] every expanded bullet enters review as accepted")
    func reviewDefaultsEverythingToAccepted() async throws {
        let store = makeTailorStore(
            profileStore: try makeProfileStore(),
            service: FixtureIntelligenceService.tailorFixture()
        )

        await store.startRun(jobDetails)

        let review = try #require(store.review)
        try #require(!review.items.isEmpty)
        for item in review.items {
            #expect(item.accepted, "nothing is pre-rejected on the user's behalf")
        }
    }

    @Test("[TAILOR-13] the reviewed outcome uses the expanded bullet for an accepted achievement")
    func acceptedBulletLandsInTheOutcome() async throws {
        let store = makeTailorStore(
            profileStore: try makeProfileStore(),
            service: FixtureIntelligenceService.tailorFixture()
        )

        await store.startRun(jobDetails)

        let review = try #require(store.review)
        let outcome = review.outcome
        try #require(outcome.items.count == 2)
        #expect(outcome.items.map(\.text) == [
            "Drove CI build times down across every product target, tightening the platform feedback loop",
            "Led cross-team incident response for a critical payments outage",
        ])
    }

    @Test("[TAILOR-14] the reviewed outcome uses the canonical text for a rejected bullet")
    func rejectedBulletFallsBackToCanonicalText() async throws {
        let store = makeTailorStore(
            profileStore: try makeProfileStore(),
            service: FixtureIntelligenceService.tailorFixture()
        )
        await store.startRun(jobDetails)
        let review = try #require(store.review)

        review.items[0].accepted = false

        let outcome = review.outcome
        try #require(outcome.items.count == 2, "rejecting keeps the achievement in the selection")
        #expect(outcome.items[0].text == "Cut CI build times across every product target")
        #expect(outcome.items[1].text == "Led cross-team incident response for a critical payments outage")
    }

    @Test("[TAILOR-15] a completed tailor run and review leave the persisted Profile unchanged")
    func tailorRunLeavesPersistedProfileUnchanged() async throws {
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }

        do {
            let profileStore = try ProfileStore(container: ProfileStore.container(at: url))
            try profileStore.load()
            try profileStore.createProfile(name: "Alex Climber", headline: "Staff Engineer")
            let role = try profileStore.addRole(
                company: "Acme", title: "Senior Engineer",
                start: Date(timeIntervalSince1970: 1_600_000_000), end: nil
            )
            try profileStore.addAchievement(to: role, text: "Cut CI build times across every product target")
            try profileStore.addAchievement(to: role, text: "Shipped the offline sync engine")
            try profileStore.addAchievement(to: role, text: "Led incident response for the payments outage")

            let store = makeTailorStore(
                profileStore: profileStore,
                service: FixtureIntelligenceService.tailorFixture()
            )
            await store.startRun(jobDetails)
            let review = try #require(store.review)
            for item in review.items {
                item.accepted = true
            }
            _ = review.outcome
        }

        let reopened = try ProfileStore(container: ProfileStore.container(at: url))
        try reopened.load()
        let profile = try #require(reopened.profile)
        #expect(profile.roles.count == 1)
        let role = try #require(profile.roles.first)
        #expect(role.orderedAchievements.map(\.text) == [
            "Cut CI build times across every product target",
            "Shipped the offline sync engine",
            "Led incident response for the payments outage",
        ], "expanded bullets never mutate Achievement.text")
        #expect(profile.skills.isEmpty, "nothing new is persisted")
    }

    @Test("[TAILOR-16] a saved API key round-trips through the Keychain store")
    func apiKeyRoundTripsThroughTheKeychain() throws {
        // A unique service name keeps the test's item away from the app's
        // real key; the defer cleans up even on failure.
        let store = KeychainAPIKeyStore(service: "app.ladder.tests.\(UUID().uuidString)")
        defer { try? store.deleteKey() }

        #expect(try store.readKey() == nil, "no key saved yet")

        try store.save(key: "sk-ant-test-key")
        #expect(try store.readKey() == "sk-ant-test-key")

        // Saving again overwrites, never duplicates.
        try store.save(key: "sk-ant-rotated")
        #expect(try store.readKey() == "sk-ant-rotated")

        try store.deleteKey()
        #expect(try store.readKey() == nil, "delete removes the key")
    }

    @Test("[TAILOR-17] a live service request carries the stored API key")
    func liveServiceRequestCarriesTheStoredKey() throws {
        let request = IntelligenceRequest(prompt: "the tailor prompt", payload: "the payload")

        let urlRequest = try AnthropicIntelligenceService.urlRequest(for: request, apiKey: "sk-ant-live")

        #expect(urlRequest.url?.absoluteString == "https://api.anthropic.com/v1/messages")
        #expect(urlRequest.httpMethod == "POST")
        #expect(urlRequest.value(forHTTPHeaderField: "x-api-key") == "sk-ant-live")
        #expect(urlRequest.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(urlRequest.value(forHTTPHeaderField: "content-type") == "application/json")

        let body = try #require(urlRequest.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["model"] as? String == "claude-sonnet-5", "the pinned Sonnet model (decisions/0003)")
        #expect(json["system"] as? String == "the tailor prompt", "the prompt travels as the system prompt")
        #expect((json["max_tokens"] as? Int ?? 0) > 0)
        let messages = try #require(json["messages"] as? [[String: Any]])
        #expect(messages.count == 1)
        #expect(messages.first?["role"] as? String == "user")
        #expect(messages.first?["content"] as? String == "the payload", "the payload travels as the user message")
    }

    @Test("[TAILOR-19] the tailor payload carries projects, education, and interests")
    func payloadCarriesNewProfileSections() async throws {
        let profileStore = try makeProfileStore()
        let project = try profileStore.addProject(
            name: "Trail Mapper", link: "https://example.com/trail-mapper",
            summary: "Offline-first hiking maps",
            details: "Built tile caching so a week's maps survive without signal."
        )
        try profileStore.tag(project, skillNamed: "Swift")
        try profileStore.addEducation(
            institution: "University of Example", qualification: "BSc Computer Science",
            start: Date(timeIntervalSince1970: 1_100_000_000),
            end: Date(timeIntervalSince1970: 1_200_000_000),
            detail: "First-class honours"
        )
        try profileStore.addInterest("climbing")
        let service = FixtureIntelligenceService.tailorFixture()
        let store = makeTailorStore(profileStore: profileStore, service: service)

        await store.startRun(jobDetails)

        let payload = try #require(await service.recordedRequests.first?.payload)
        #expect(payload.contains("Trail Mapper"))
        #expect(payload.contains("Built tile caching so a week's maps survive without signal."))
        #expect(payload.contains(#""p1""#), "whole projects carry p-prefixed ids")
        #expect(payload.contains(#""tags""#), "project Tags travel under the tags key")
        #expect(payload.contains("University of Example"))
        #expect(payload.contains("First-class honours"))
        #expect(payload.contains("climbing"))
    }

    @Test("[TAILOR-22] a selection may include a whole project")
    func wholeProjectSelectionsResolve() async throws {
        let profileStore = try makeProfileStore()
        let project = try profileStore.addProject(
            name: "Trail Mapper",
            details: "Built tile caching so a week's maps survive without signal."
        )
        try profileStore.tag(project, skillNamed: "Swift")
        let selectingProject = Data("""
        {
          "summary": "Engineer with production mapping experience.",
          "selections": [],
          "projects": ["p1"],
          "gaps": [],
          "rationale": "The project work fits the JD directly."
        }
        """.utf8)
        let store = makeTailorStore(
            profileStore: profileStore,
            service: FixtureIntelligenceService(returning: selectingProject)
        )

        await store.startRun(jobDetails)

        #expect(store.phase == .review)
        let review = try #require(store.review)
        let selected = try #require(review.selectedProjects.first)
        #expect(selected.name == "Trail Mapper")
        let outcomeProject = try #require(review.outcome.projects.first)
        #expect(
            outcomeProject.details == "Built tile caching so a week's maps survive without signal.",
            "the description travels verbatim — never expanded or reworded"
        )
        #expect(outcomeProject.tags == ["Swift"])
    }

    @Test("[TAILOR-22] a result selecting a project id not in the payload feeds the repair path")
    func unknownProjectIDFailsValidation() async throws {
        let profileStore = try makeProfileStore()
        let selectingUnknownProject = Data("""
        {
          "summary": "Summary.",
          "selections": [],
          "projects": ["p9"],
          "gaps": [],
          "rationale": "Rationale."
        }
        """.utf8)
        let store = makeTailorStore(
            profileStore: profileStore,
            service: FixtureIntelligenceService(returning: selectingUnknownProject)
        )

        await store.startRun(jobDetails)

        #expect(store.phase == .failed(.resultInvalid), "an invalid-then-invalid sequence fails the run")
    }

    @Test("[TAILOR-3] a Profile whose only selectable content is a project is not refused")
    func projectOnlyProfilePassesTheGuard() async throws {
        let profileStore = try ProfileStore(container: ProfileStore.container(inMemory: true))
        try profileStore.load()
        try profileStore.createProfile(name: "Alex Climber", headline: "Staff Engineer")
        try profileStore.addProject(
            name: "Trail Mapper",
            details: "Built tile caching so a week's maps survive without signal."
        )
        let selectingProject = Data("""
        {
          "summary": "Engineer whose project work fits the JD.",
          "selections": [],
          "projects": ["p1"],
          "gaps": [],
          "rationale": "Project work only."
        }
        """.utf8)
        let store = makeTailorStore(
            profileStore: profileStore,
            service: FixtureIntelligenceService(returning: selectingProject)
        )

        await store.startRun(jobDetails)

        #expect(store.phase == .review, "projects are selectable content, not just role achievements")
    }

    @Test("[TAILOR-21] the reviewed outcome carries the result's generated CV summary verbatim")
    func summaryTravelsIntoTheOutcomeVerbatim() async throws {
        let store = makeTailorStore(
            profileStore: try makeProfileStore(),
            service: FixtureIntelligenceService.tailorFixture()
        )

        await store.startRun(jobDetails)

        let review = try #require(store.review)
        let expected = "Platform-minded senior engineer with a track record of CI performance work and cross-team incident response, matched to platform-reliability ownership."
        #expect(review.summary == expected)
        #expect(review.outcome.summary == expected, "verbatim — never summarised or re-derived")

        // Missing from the schema means a validation failure, which feeds
        // the repair path ([TAILOR-9]) — a summary-less repair fails the run.
        let summaryless = Data("""
        {
          "selections": [],
          "gaps": [],
          "rationale": "…"
        }
        """.utf8)
        let failing = makeTailorStore(
            profileStore: try makeProfileStore(),
            service: FixtureIntelligenceService(returning: [summaryless, summaryless])
        )
        await failing.startRun(jobDetails)
        #expect(failing.phase == .failed(.resultInvalid))
    }

    @Test("[TAILOR-18] a tailor result wrapped in a markdown code fence produces a review")
    func fencedResultProducesReview() async throws {
        let profileStore = try makeProfileStore()
        let bareJSON = try Data(contentsOf: #require(
            Bundle.main.url(forResource: "tailor-result", withExtension: "json", subdirectory: "Fixtures"),
            "tailor-result.json missing from the bundled Fixtures folder"
        ))
        let fenced = Data("```json\n\(String(decoding: bareJSON, as: UTF8.self))\n```".utf8)
        let service = FixtureIntelligenceService(returning: fenced)
        let store = makeTailorStore(profileStore: profileStore, service: service)

        await store.startRun(jobDetails)

        #expect(store.phase == .review)
        let review = try #require(store.review)
        #expect(review.items.map(\.achievement.text) == [
            "Cut CI build times across every product target",
            "Led incident response for the payments outage",
        ], "the fenced result reads exactly as the bare one")
        // The fence never costs the single repair request.
        #expect(await service.recordedRequests.count == 1)
    }
}

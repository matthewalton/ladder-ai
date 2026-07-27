import Foundation
import SwiftData
import Testing

@testable import Ladder

/// The JD scan (root `CONTEXT.md`): pool-aware, deterministic Match,
/// transient suggestions (decisions/0011, 0013). Fixture service and fake
/// key stores everywhere — no network.
@MainActor
struct JDScanFlowTests {
    /// One context holding everything the scan reads: a Profile whose pool
    /// is Swift, Kubernetes (alias "k8s"), SwiftUI — the shape the canned
    /// fixture response speaks to — and an Application carrying a JD.
    private func makeWorld() throws -> (context: ModelContext, application: Application) {
        let container = try ProfileStore.container(inMemory: true)
        let context = ModelContext(container)
        let profile = Profile(name: "Alex Climber", headline: "")
        context.insert(profile)
        let kubernetes = SkillTag(name: "Kubernetes")
        kubernetes.aliases = ["k8s"]
        profile.skills = [SkillTag(name: "Swift"), kubernetes, SkillTag(name: "SwiftUI")]
        let application = Application(
            company: "Acme",
            roleTitle: "iOS Engineer",
            jobDescription: "Swift and Kubernetes (k8s); GraphQL and team leadership a plus.",
            status: .draft)
        context.insert(application)
        try context.save()
        return (context, application)
    }

    private func makeScanStore(
        service: FixtureIntelligenceService,
        keyStore: any APIKeyStore = InMemoryAPIKeyStore(key: "test-key")
    ) -> JDScanStore {
        JDScanStore(keyStore: keyStore, makeIntelligence: { _ in service })
    }

    @Test("[TAILOR-27] a JD scan stores a Match on the Application")
    func scanStoresMatch() async throws {
        let (context, application) = try makeWorld()
        let service = FixtureIntelligenceService.jdScanFixture()
        let store = makeScanStore(service: service)

        await store.scan(application)

        #expect(store.phase == .scanned)
        let match = try #require(application.match)
        #expect(
            Set(match.matchedTags.map(\.name)) == ["Swift", "Kubernetes"],
            "\"swift\" resolves by casing, \"k8s\" through the Alias — live pool references")
        #expect(
            match.matchedTags.count == 2,
            "the fixture's \"k8s\" and \"kubernetes\" both resolve to the one Kubernetes Tag — one reference")
        #expect(match.vocabularyGaps == ["GraphQL", "Team leadership"], "gaps land verbatim as strings")
        let pool = Set((try #require(try context.fetch(FetchDescriptor<Profile>()).first)).skills.map(\.name))
        #expect(pool == ["Swift", "Kubernetes", "SwiftUI"], "the scan writes the Match, never the pool")

        // A fresh context sees the Match, so it saved.
        let fresh = ModelContext(context.container)
        let saved = try #require(try fresh.fetch(FetchDescriptor<Match>()).first)
        #expect(saved.matchedTags.count == 2)
        #expect(saved.vocabularyGaps == ["GraphQL", "Team leadership"])
        #expect(saved.application?.company == "Acme")
    }

    @Test("[TAILOR-28] the scan request carries the versioned jd-scan prompt and the pool vocabulary")
    func requestCarriesPromptAndVocabulary() async throws {
        let (_, application) = try makeWorld()
        let service = FixtureIntelligenceService.jdScanFixture()
        let store = makeScanStore(service: service)

        await store.scan(application)

        let request = try #require(await service.recordedRequests.first)
        #expect(
            request.prompt == (try JDScanPrompt.text()),
            "the prompt travels verbatim from the versioned Prompts/jd-scan.md")
        #expect(
            request.payload.contains("Swift and Kubernetes (k8s); GraphQL and team leadership a plus."),
            "the Application's job description travels verbatim")
        #expect(request.payload.contains("Kubernetes"), "the vocabulary carries primary names")
        #expect(request.payload.contains("k8s"), "…and Aliases")
        #expect(request.payload.contains("SwiftUI"), "…for every pool Tag")
    }

    @Test("[TAILOR-29] a scan result matching a name absent from the pool fails validation")
    func matchedNameOutsidePoolFailsValidation() async throws {
        let (_, application) = try makeWorld()
        let invented = Data(#"{"matched": ["Rust"], "gaps": [], "suggestions": []}"#.utf8)
        let service = FixtureIntelligenceService(returning: [invented, invented])
        let store = makeScanStore(service: service)

        await store.scan(application)

        #expect(store.phase == .failed(.resultInvalid(reason: "matched name 'Rust' resolves to no pool Tag")))
        let repair = try #require(await service.recordedRequests.dropFirst().first)
        #expect(
            repair.payload.contains("resolves to no pool Tag"),
            "the referential failure feeds the repair path exactly like a schema mismatch")
        #expect(application.match == nil, "no Match lands from an invented vocabulary")
    }

    @Test("[TAILOR-29] a valid repair after a referential failure produces the Match")
    func validRepairAfterReferentialFailureRecovers() async throws {
        let (_, application) = try makeWorld()
        let invented = Data(#"{"matched": ["Rust"], "gaps": [], "suggestions": []}"#.utf8)
        let valid = Data(#"{"matched": ["Swift"], "gaps": ["GraphQL"], "suggestions": []}"#.utf8)
        let service = FixtureIntelligenceService(returning: [invented, valid])
        let store = makeScanStore(service: service)

        await store.scan(application)

        #expect(store.phase == .scanned)
        #expect(application.match?.matchedTags.map(\.name) == ["Swift"])
    }

    @Test("[TAILOR-30] a JD scan returns its Tag suggestions without persisting them")
    func suggestionsAreTransient() async throws {
        let (context, application) = try makeWorld()
        let service = FixtureIntelligenceService.jdScanFixture()
        let store = makeScanStore(service: service)

        await store.scan(application)

        #expect(store.suggestions.count == 2, "the canned fixture carries both pool-level kinds")
        #expect(store.suggestions.first?.change == .mint(name: "GraphQL"))
        #expect(store.suggestions.last?.change == .alias("swift ui", onTagNamed: "SwiftUI"))

        // A fresh context sees the Match without a trace of the proposals:
        // pool untouched, no alias recorded, only matched/gaps/scannedAt.
        let fresh = ModelContext(context.container)
        let profile = try #require(try fresh.fetch(FetchDescriptor<Profile>()).first)
        #expect(Set(profile.skills.map(\.name)) == ["Swift", "Kubernetes", "SwiftUI"])
        let swiftUI = try #require(profile.skills.first { $0.name == "SwiftUI" })
        #expect(swiftUI.aliases == [], "the proposed alias never lands without confirmation")
        #expect(try fresh.fetch(FetchDescriptor<Match>()).count == 1)
    }

    @Test("[TAILOR-30] a scan result proposing an attach fails validation")
    func attachSuggestionFailsValidation() async throws {
        let (_, application) = try makeWorld()
        let attach = Data(
            #"{"matched": [], "gaps": [], "suggestions": [{"kind": "attach", "tag": "Swift"}]}"#.utf8)
        let service = FixtureIntelligenceService(returning: [attach, attach])
        let store = makeScanStore(service: service)

        await store.scan(application)

        #expect(
            store.phase == .failed(.resultInvalid(reason: "suggestion 1 has unknown kind 'attach'")),
            "attach is a point-door kind — the scan schema rejects it (decisions/0013)")
    }

    @Test("[TAILOR-31] an invalid scan response gets exactly one repair request")
    func invalidResponseGetsExactlyOneRepair() async throws {
        let (_, application) = try makeWorld()
        let missingGaps = Data(#"{"matched": [], "suggestions": []}"#.utf8)
        let valid = Data(#"{"matched": ["Swift"], "gaps": [], "suggestions": []}"#.utf8)
        let service = FixtureIntelligenceService(returning: [missingGaps, valid])
        let store = makeScanStore(service: service)

        await store.scan(application)

        #expect(store.phase == .scanned, "an invalid-then-valid sequence recovers")
        let requests = await service.recordedRequests
        #expect(requests.count == 2, "two requests, never three")
        let repair = try #require(requests.last)
        #expect(repair.payload.contains("the response has no gaps array"))
        #expect(repair.payload.contains(#""matched": [],"#), "the repair carries the invalid response")
    }

    @Test("[TAILOR-31] a fenced-but-valid scan response consumes no repair")
    func fencedResponseConsumesNoRepair() async throws {
        let (_, application) = try makeWorld()
        let fenced = Data(
            "```json\n{\"matched\": [\"Swift\"], \"gaps\": [], \"suggestions\": []}\n```".utf8)
        let service = FixtureIntelligenceService(returning: [fenced])
        let store = makeScanStore(service: service)

        await store.scan(application)

        #expect(store.phase == .scanned)
        #expect(await service.recordedRequests.count == 1, "the fence is presentation, not content")
        #expect(application.match?.matchedTags.map(\.name) == ["Swift"])
    }

    @Test("[TAILOR-32] a scan whose repair response fails validation leaves the Application's Match unchanged")
    func failedRepairLeavesMatchUnchanged() async throws {
        let (context, application) = try makeWorld()
        let first = makeScanStore(service: FixtureIntelligenceService.jdScanFixture())
        await first.scan(application)
        #expect(first.phase == .scanned)
        let scannedAt = try #require(application.match?.scannedAt)

        let invalid = Data(#"{"nonsense": true}"#.utf8)
        let store = makeScanStore(service: FixtureIntelligenceService(returning: [invalid, invalid]))
        await store.scan(application)

        #expect(store.phase == .failed(.resultInvalid(reason: "the response has no matched array")))
        let match = try #require(application.match, "the existing Match survives the failed scan")
        #expect(Set(match.matchedTags.map(\.name)) == ["Swift", "Kubernetes"])
        #expect(match.vocabularyGaps == ["GraphQL", "Team leadership"])
        #expect(match.scannedAt == scannedAt, "not even the timestamp moves")
        #expect(try context.fetch(FetchDescriptor<Match>()).count == 1, "no partial Match is ever written")
    }

    @Test("[TAILOR-32] a failed scan on a never-scanned Application still stores no Match")
    func failedScanOnFreshApplicationStoresNothing() async throws {
        let (context, application) = try makeWorld()
        let invalid = Data(#"{"nonsense": true}"#.utf8)
        let store = makeScanStore(service: FixtureIntelligenceService(returning: [invalid, invalid]))

        await store.scan(application)

        if case .failed(.resultInvalid) = store.phase {} else {
            Issue.record("expected a resultInvalid failure, got \(store.phase)")
        }
        #expect(application.match == nil)
        #expect(try context.fetch(FetchDescriptor<Match>()).isEmpty)
    }

    @Test("[TAILOR-33] a JD scan on an empty job description is refused")
    func emptyJobDescriptionRefused() async throws {
        let (context, application) = try makeWorld()
        let first = makeScanStore(service: FixtureIntelligenceService.jdScanFixture())
        await first.scan(application)
        let match = try #require(application.match)
        application.jobDescription = "  \n\t "
        try context.save()

        let service = FixtureIntelligenceService.jdScanFixture()
        let store = makeScanStore(service: service)
        await store.scan(application)

        #expect(store.phase == .failed(.jobDescriptionRequired), "whitespace-only counts as empty")
        #expect(await service.recordedRequests.isEmpty, "refused before any service call")
        #expect(application.match === match, "the existing Match is unchanged")
    }

    @Test("[TAILOR-34] a JD scan with no API key stored is refused")
    func missingAPIKeyRefused() async throws {
        let (_, application) = try makeWorld()
        let service = FixtureIntelligenceService.jdScanFixture()
        let store = makeScanStore(service: service, keyStore: InMemoryAPIKeyStore())

        await store.scan(application)

        #expect(store.phase == .failed(.apiKeyRequired))
        #expect(
            await service.recordedRequests.isEmpty,
            "checked before any service call — and production never falls back to fixture data")
        #expect(application.match == nil)
    }

    @Test("[TAILOR-35] the scan run creates its live service with the stored API key")
    func scanCreatesServiceWithStoredKey() async throws {
        let (_, application) = try makeWorld()
        let keyStore = InMemoryAPIKeyStore(key: "sk-ladder-test")
        let service = FixtureIntelligenceService.jdScanFixture()
        var handedKeys: [String] = []
        let store = JDScanStore(
            keyStore: keyStore,
            makeIntelligence: { key in
                handedKeys.append(key)
                return service
            })

        await store.scan(application)

        #expect(handedKeys == ["sk-ladder-test"], "the factory receives exactly the stored key")
        #expect(store.phase == .scanned)
    }

    @Test("[TAILOR-36] a second JD scan replaces the Application's Match")
    func secondScanReplacesMatch() async throws {
        let (context, application) = try makeWorld()
        let first = makeScanStore(service: FixtureIntelligenceService.jdScanFixture())
        await first.scan(application)
        let firstScannedAt = try #require(application.match?.scannedAt)

        let narrower = Data(#"{"matched": ["SwiftUI"], "gaps": ["Rust"], "suggestions": []}"#.utf8)
        let store = makeScanStore(service: FixtureIntelligenceService(returning: [narrower]))
        await store.scan(application)

        #expect(store.phase == .scanned)
        let match = try #require(application.match)
        #expect(match.matchedTags.map(\.name) == ["SwiftUI"], "the previous matched references are gone")
        #expect(match.vocabularyGaps == ["Rust"])
        #expect(match.scannedAt > firstScannedAt, "scannedAt moves")
        #expect(
            try context.fetch(FetchDescriptor<Match>()).count == 1,
            "at most one Match per Application — no orphans")
    }
}

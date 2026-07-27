import Foundation
import SwiftData
import Testing

@testable import Ladder

/// The scan-first flow (decisions/0014, 0015): scan → Match review →
/// tailor run → review, one fixture service recording every request — the
/// request order is the flow's proof. No network anywhere.
@MainActor
struct TailorFlowStoreTests {
    /// A ProfileStore world the canned jd-scan and tailor-result fixtures
    /// both speak to: three achievements (payload ids a1–a3; the tailor
    /// fixture selects a1 and a3) tagged from the pool Swift, Kubernetes
    /// (alias "k8s"), SwiftUI, Leadership — and an Application on the same
    /// container carrying the JD.
    private func makeWorld() throws -> (profileStore: ProfileStore, application: Application) {
        let profileStore = try ProfileStore(container: ProfileStore.container(inMemory: true))
        try profileStore.load()
        try profileStore.createProfile(name: "Alex Climber", headline: "Staff Engineer")
        let role = try profileStore.addRole(
            company: "Acme", title: "Senior Engineer",
            start: Date(timeIntervalSince1970: 1_600_000_000), end: nil
        )
        let first = try profileStore.addAchievement(
            to: role, text: "Cut CI build times across every product target")
        let second = try profileStore.addAchievement(
            to: role, text: "Shipped the offline sync engine")
        let third = try profileStore.addAchievement(
            to: role, text: "Led incident response for the payments outage")
        try profileStore.tag(first, skillNamed: "Swift")
        let kubernetes = try profileStore.tag(first, skillNamed: "Kubernetes")
        try profileStore.recordAlias("k8s", on: kubernetes)
        try profileStore.tag(second, skillNamed: "SwiftUI")
        try profileStore.tag(third, skillNamed: "Leadership")

        let context = ModelContext(profileStore.container)
        let application = Application(
            company: "Summit Labs", roleTitle: "Platform Engineer",
            jobDescription: "Own platform reliability. Kubernetes, CI at scale, incident response.",
            status: .draft)
        context.insert(application)
        try context.save()
        return (profileStore, application)
    }

    private func makeFlow(
        profileStore: ProfileStore,
        application: Application,
        service: FixtureIntelligenceService,
        keyStore: any APIKeyStore = InMemoryAPIKeyStore(key: "sk-test")
    ) -> TailorFlowStore {
        TailorFlowStore(
            profileStore: profileStore,
            application: application,
            keyStore: keyStore,
            makeIntelligence: { _ in service })
    }

    private func fixtureData(_ name: String) throws -> Data {
        let url = try #require(
            Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    private var jobDetails: JobDetails {
        JobDetails(
            company: "Summit Labs",
            roleTitle: "Platform Engineer",
            jobDescription: "Own platform reliability. Kubernetes, CI at scale, incident response.")
    }

    // MARK: - [TAILOR-43] the scan runs first

    @Test("[TAILOR-43] a tailor presentation runs the JD scan before any tailor request")
    func presentationScansFirst() async throws {
        let (profileStore, application) = try makeWorld()
        let service = FixtureIntelligenceService(returning: [try fixtureData("jd-scan")])
        let flow = makeFlow(profileStore: profileStore, application: application, service: service)

        await flow.start()

        #expect(flow.phase == .matchReview, "the flow holds in the Match review after the scan")
        let requests = await service.recordedRequests
        #expect(requests.count == 1, "one scan request, no tailor request")
        #expect(
            requests.first?.prompt == (try JDScanPrompt.text()),
            "the flow's first request is the jd-scan prompt")
        #expect(application.match != nil, "the scan stored the Match ([TAILOR-27])")
    }

    @Test("[TAILOR-43] an existing Match never short-circuits the scan")
    func existingMatchStillRescans() async throws {
        let (profileStore, application) = try makeWorld()
        let first = JDScanStore(
            keyStore: InMemoryAPIKeyStore(key: "sk-test"),
            makeIntelligence: { _ in FixtureIntelligenceService.jdScanFixture() })
        await first.scan(application)
        let firstScannedAt = try #require(application.match?.scannedAt)

        let service = FixtureIntelligenceService(returning: [try fixtureData("jd-scan")])
        let flow = makeFlow(profileStore: profileStore, application: application, service: service)
        await flow.start()

        #expect(await service.recordedRequests.count == 1, "the presentation re-scanned")
        let scannedAt = try #require(application.match?.scannedAt)
        #expect(scannedAt > firstScannedAt, "the Match tracks the pool — refreshed, not reused")
    }

    @Test("[TAILOR-43] presenting with nothing selectable on the Profile refuses before any service call")
    func emptyProfileRefusesBeforeScanning() async throws {
        let profileStore = try ProfileStore(container: ProfileStore.container(inMemory: true))
        try profileStore.load()
        try profileStore.createProfile(name: "Alex Climber", headline: "")
        let context = ModelContext(profileStore.container)
        let application = Application(
            company: "Summit Labs", roleTitle: "Platform Engineer",
            jobDescription: "Own platform reliability.", status: .draft)
        context.insert(application)
        try context.save()
        let service = FixtureIntelligenceService(returning: [try fixtureData("jd-scan")])
        let flow = makeFlow(profileStore: profileStore, application: application, service: service)

        await flow.start()

        #expect(flow.phase == .tailorFailed(.achievementsRequired), "the [TAILOR-3] refusal keeps its place")
        #expect(await service.recordedRequests.isEmpty, "refused before any service call — no scan either")
    }

    // MARK: - [TAILOR-44] a failed scan fails the flow

    @Test("[TAILOR-44] a failed JD scan ends the tailor flow with no tailor request sent")
    func failedScanEndsFlow() async throws {
        let (profileStore, application) = try makeWorld()
        let invalid = Data(#"{"nonsense": true}"#.utf8)
        let service = FixtureIntelligenceService(
            returning: [invalid, invalid, try fixtureData("jd-scan")])
        let flow = makeFlow(profileStore: profileStore, application: application, service: service)

        await flow.start()

        #expect(
            flow.phase == .scanFailed(.resultInvalid(reason: "the response has no matched array")),
            "the reason surfaces; there is no fallback to a raw JD or a stale Match")
        let scanPrompt = try JDScanPrompt.text()
        let requests = await service.recordedRequests
        #expect(requests.count == 2, "the scan and its single repair — nothing more")
        #expect(
            requests.allSatisfy { $0.prompt == scanPrompt },
            "no tailor request was ever sent")

        // Retry re-runs from the scan (decisions/0014) — the third canned
        // response is valid, so the retried flow reaches the Match review.
        await flow.retry()
        #expect(flow.phase == .matchReview)
        #expect(await service.recordedRequests.count == 3, "retry scanned again")
    }

    // MARK: - [TAILOR-46] the presented review state

    @Test("[TAILOR-46] the Match review presents the Match score with its matched Tags, vocabulary gaps and Tag suggestions")
    func matchReviewPresentsScanOutcome() async throws {
        let (profileStore, application) = try makeWorld()
        let service = FixtureIntelligenceService(returning: [try fixtureData("jd-scan")])
        let flow = makeFlow(profileStore: profileStore, application: application, service: service)

        await flow.start()

        let review = try #require(flow.matchReview)
        #expect(Set(review.matchedTagNames) == ["Swift", "Kubernetes"], "matched Tags by primary name")
        #expect(review.vocabularyGaps == ["GraphQL", "Team leadership"], "gaps verbatim")
        #expect(review.score == 50, "2 matched, 2 gaps — [TAILOR-41]'s derivation")
        #expect(review.suggestions.count == 3, "every transient suggestion appears")
        #expect(
            review.suggestions.allSatisfy { !$0.isAccepted },
            "unchecked on entry — claiming a skill is opt-in, never opt-out")
        #expect(
            review.suggestions.allSatisfy { !$0.proposal.rationale.isEmpty },
            "each suggestion carries its rationale")
    }

    @Test("[TAILOR-46] a Match with no asks presents no score")
    func matchReviewWithNoAsksHasNoScore() async throws {
        let (profileStore, application) = try makeWorld()
        let empty = Data(#"{"matched": [], "gaps": [], "suggestions": []}"#.utf8)
        let service = FixtureIntelligenceService(returning: [empty])
        let flow = makeFlow(profileStore: profileStore, application: application, service: service)

        await flow.start()

        let review = try #require(flow.matchReview)
        #expect(review.score == nil, "no asks means no score — never a fake 100")
    }

    // MARK: - [TAILOR-47] the live offline recompute

    @Test("[TAILOR-47] toggling a Tag suggestion recomputes the review's score without any service request")
    func togglingRecomputesScoreOffline() async throws {
        let (profileStore, application) = try makeWorld()
        let service = FixtureIntelligenceService(returning: [try fixtureData("jd-scan")])
        let flow = makeFlow(profileStore: profileStore, application: application, service: service)
        await flow.start()
        let review = try #require(flow.matchReview)
        #expect(review.score == 50)

        review.suggestions[0].isAccepted = true
        #expect(review.score == 75, "the resolving mint counts its gap as matched while checked: 3 ÷ 4")

        review.suggestions[1].isAccepted = true
        #expect(review.score == 100, "the resolving alias dissolves the second gap: 4 ÷ 4")

        review.suggestions[2].isAccepted = true
        #expect(review.score == 100, "a suggestion with no resolves moves the score by nothing")

        review.suggestions[1].isAccepted = false
        #expect(review.score == 75, "unchecking returns the gap")
        review.suggestions[0].isAccepted = false
        #expect(review.score == 50)

        #expect(
            await service.recordedRequests.count == 1,
            "zero requests across any number of toggles — the scan's own request is the only one")
    }

    @Test("[TAILOR-47] two accepted suggestions resolving the same gap count it once")
    func duplicateResolvesCountsOnce() async throws {
        let (profileStore, application) = try makeWorld()
        let response = Data(
            #"{"matched": ["Swift"], "gaps": ["GraphQL"], "suggestions": [{"kind": "mint", "name": "GraphQL", "resolves": "GraphQL"}, {"kind": "alias", "alias": "graphql", "tag": "Swift", "resolves": "GraphQL"}]}"#
                .utf8)
        let service = FixtureIntelligenceService(returning: [response])
        let flow = makeFlow(profileStore: profileStore, application: application, service: service)
        await flow.start()
        let review = try #require(flow.matchReview)

        review.suggestions[0].isAccepted = true
        review.suggestions[1].isAccepted = true

        #expect(review.score == 100, "one gap dissolved once: 2 ÷ 2, never 3 ÷ 1")
    }

    // MARK: - [TAILOR-48/49/50] confirmation and cancel

    @Test("[TAILOR-48] confirming the Match review writes each accepted suggestion to the Tag pool")
    func confirmingWritesAcceptedSuggestions() async throws {
        let (profileStore, application) = try makeWorld()
        let service = FixtureIntelligenceService(
            returning: [try fixtureData("jd-scan"), try fixtureData("tailor-result")])
        let flow = makeFlow(profileStore: profileStore, application: application, service: service)
        await flow.start()
        let review = try #require(flow.matchReview)
        for index in review.suggestions.indices {
            review.suggestions[index].isAccepted = true
        }

        await flow.confirmMatchReview()

        // A fresh context proves the pool writes persisted.
        let fresh = ModelContext(profileStore.container)
        let profile = try #require(try fresh.fetch(FetchDescriptor<Profile>()).first)
        let poolNames = Set(profile.skills.map(\.name))
        #expect(
            poolNames == ["Swift", "Kubernetes", "SwiftUI", "Leadership", "GraphQL"],
            "the accepted mint lands in its curated casing")
        let leadership = try #require(profile.skills.first { $0.name == "Leadership" })
        #expect(leadership.aliases == ["team leadership"], "the accepted alias lands lowercase")
        let swiftUI = try #require(profile.skills.first { $0.name == "SwiftUI" })
        #expect(swiftUI.aliases == ["swift ui"], "the non-resolving alias lands too")
    }

    @Test("[TAILOR-48] unchecked suggestions land nothing")
    func uncheckedSuggestionsLandNothing() async throws {
        let (profileStore, application) = try makeWorld()
        let service = FixtureIntelligenceService(
            returning: [try fixtureData("jd-scan"), try fixtureData("tailor-result")])
        let flow = makeFlow(profileStore: profileStore, application: application, service: service)
        await flow.start()
        let review = try #require(flow.matchReview)
        review.suggestions[0].isAccepted = true  // the mint alone

        await flow.confirmMatchReview()

        let fresh = ModelContext(profileStore.container)
        let profile = try #require(try fresh.fetch(FetchDescriptor<Profile>()).first)
        #expect(profile.skills.contains { $0.name == "GraphQL" })
        #expect(
            profile.skills.allSatisfy { $0.name == "Kubernetes" ? $0.aliases == ["k8s"] : $0.aliases.isEmpty },
            "neither unchecked alias landed")
    }

    @Test("[TAILOR-48] a mint whose name already resolves attaches the existing Tag, never a duplicate")
    func staleMintResolvesInsteadOfDuplicating() async throws {
        let (profileStore, application) = try makeWorld()
        let scan = Data(
            #"{"matched": [], "gaps": ["Swift UI"], "suggestions": [{"kind": "mint", "name": "SwiftUI", "resolves": "Swift UI"}]}"#
                .utf8)
        let service = FixtureIntelligenceService(
            returning: [scan, try fixtureData("tailor-result")])
        let flow = makeFlow(profileStore: profileStore, application: application, service: service)
        await flow.start()
        let review = try #require(flow.matchReview)
        review.suggestions[0].isAccepted = true

        await flow.confirmMatchReview()

        let fresh = ModelContext(profileStore.container)
        let profile = try #require(try fresh.fetch(FetchDescriptor<Profile>()).first)
        #expect(
            profile.skills.filter { $0.name.caseInsensitiveCompare("SwiftUI") == .orderedSame }.count == 1,
            "alias-aware resolution at confirm time — the [PROFILE-34] stance")
        let match = try #require(application.match)
        #expect(match.matchedTags.map(\.name) == ["SwiftUI"], "the resolved gap references the existing Tag")
    }

    @Test("[TAILOR-48] a colliding alias is refused without derailing the other accepted suggestions")
    func collidingAliasRefusedIndependently() async throws {
        let (profileStore, application) = try makeWorld()
        let scan = Data(
            #"{"matched": [], "gaps": ["GraphQL"], "suggestions": [{"kind": "alias", "alias": "swift", "tag": "SwiftUI"}, {"kind": "mint", "name": "GraphQL", "resolves": "GraphQL"}]}"#
                .utf8)
        let service = FixtureIntelligenceService(
            returning: [scan, try fixtureData("tailor-result")])
        let flow = makeFlow(profileStore: profileStore, application: application, service: service)
        await flow.start()
        let review = try #require(flow.matchReview)
        for index in review.suggestions.indices {
            review.suggestions[index].isAccepted = true
        }

        await flow.confirmMatchReview()

        let fresh = ModelContext(profileStore.container)
        let profile = try #require(try fresh.fetch(FetchDescriptor<Profile>()).first)
        let swiftUI = try #require(profile.skills.first { $0.name == "SwiftUI" })
        #expect(swiftUI.aliases == [], "\"swift\" collides with the Swift primary — refused ([PROFILE-27])")
        #expect(profile.skills.contains { $0.name == "GraphQL" }, "the mint landed regardless")
        #expect(!flow.confirmationNotes.isEmpty, "the refusal surfaces rather than passing silently")
    }

    @Test("[TAILOR-49] a confirmed resolving suggestion moves its gap into the Match's matched Tags")
    func confirmedResolvingSuggestionMovesItsGap() async throws {
        let (profileStore, application) = try makeWorld()
        let service = FixtureIntelligenceService(
            returning: [try fixtureData("jd-scan"), try fixtureData("tailor-result")])
        let flow = makeFlow(profileStore: profileStore, application: application, service: service)
        await flow.start()
        let review = try #require(flow.matchReview)
        let scannedAt = try #require(application.match?.scannedAt)
        review.suggestions[0].isAccepted = true  // mint GraphQL, resolves "GraphQL"
        review.suggestions[1].isAccepted = true  // alias on Leadership, resolves "Team leadership"
        let displayedScore = review.score

        await flow.confirmMatchReview()

        let fresh = ModelContext(profileStore.container)
        let match = try #require(try fresh.fetch(FetchDescriptor<Match>()).first)
        #expect(match.vocabularyGaps.isEmpty, "both resolved gaps left vocabularyGaps")
        #expect(
            Set(match.matchedTags.map(\.name)) == ["Swift", "Kubernetes", "GraphQL", "Leadership"],
            "the minted Tag and the alias's Tag joined the matched Tags")
        #expect(match.scannedAt == scannedAt, "no scan ran — scannedAt does not move")
        #expect(match.score == 100)
        #expect(match.score == displayedScore, "the score the user watched survives confirmation")
    }

    @Test("[TAILOR-49] a resolving suggestion for an already-matched Tag lands no second reference")
    func resolvingToMatchedTagAddsNoDuplicate() async throws {
        let (profileStore, application) = try makeWorld()
        let scan = Data(
            #"{"matched": ["Swift"], "gaps": ["GraphQL"], "suggestions": [{"kind": "alias", "alias": "graphql", "tag": "Swift", "resolves": "GraphQL"}]}"#
                .utf8)
        let service = FixtureIntelligenceService(
            returning: [scan, try fixtureData("tailor-result")])
        let flow = makeFlow(profileStore: profileStore, application: application, service: service)
        await flow.start()
        let review = try #require(flow.matchReview)
        review.suggestions[0].isAccepted = true

        await flow.confirmMatchReview()

        let match = try #require(application.match)
        #expect(match.matchedTags.map(\.name) == ["Swift"], "one reference — the gap just goes")
        #expect(match.vocabularyGaps.isEmpty)
    }

    @Test("[TAILOR-50] cancelling the Match review leaves the pool and Match unchanged")
    func cancellingWritesNothing() async throws {
        let (profileStore, application) = try makeWorld()
        let service = FixtureIntelligenceService(returning: [try fixtureData("jd-scan")])
        let flow = makeFlow(profileStore: profileStore, application: application, service: service)
        await flow.start()
        let review = try #require(flow.matchReview)
        let scannedAt = try #require(application.match?.scannedAt)
        review.suggestions[0].isAccepted = true
        review.suggestions[1].isAccepted = true

        flow.cancelMatchReview()

        let fresh = ModelContext(profileStore.container)
        let profile = try #require(try fresh.fetch(FetchDescriptor<Profile>()).first)
        #expect(
            Set(profile.skills.map(\.name)) == ["Swift", "Kubernetes", "SwiftUI", "Leadership"],
            "checked checkboxes included — only confirmation writes")
        #expect(
            profile.skills.allSatisfy { $0.name == "Kubernetes" ? $0.aliases == ["k8s"] : $0.aliases.isEmpty },
            "no alias landed")
        let match = try #require(try fresh.fetch(FetchDescriptor<Match>()).first)
        #expect(Set(match.matchedTags.map(\.name)) == ["Swift", "Kubernetes"])
        #expect(match.vocabularyGaps == ["GraphQL", "Team leadership"])
        #expect(match.scannedAt == scannedAt)
        #expect(await service.recordedRequests.count == 1, "and no tailor request was sent ([TAILOR-45])")
    }

    // MARK: - [TAILOR-52/53] the annotated, ordered payload

    /// Drills to the payload's profile dictionary.
    private func decodedProfile(from json: String) throws -> [String: Any] {
        let root = try #require(
            try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        return try #require(root["profile"] as? [String: Any])
    }

    @Test("[TAILOR-52] the tailor payload annotates each point with its overlap of the Match's matched Tags")
    func payloadAnnotatesEachPointWithOverlap() async throws {
        let (profileStore, _) = try makeWorld()
        let ladder = try profileStore.addProject(name: "Ladder", details: "Interview companion")
        try profileStore.tag(ladder, skillNamed: "Swift")
        try profileStore.addProject(name: "Beacon", details: "Weather worker")
        let profile = try #require(profileStore.profile)

        let payload = try TailorPayload(
            profile: profile, details: jobDetails, matchedTagNames: ["Swift", "Kubernetes"])

        let profileDict = try decodedProfile(from: payload.json)
        let roles = try #require(profileDict["roles"] as? [[String: Any]])
        let achievements = try #require(roles.first?["achievements"] as? [[String: Any]])
        let first = try #require(achievements.first)
        let firstOverlap = try #require(first["overlap"] as? [String: Any])
        #expect(first["text"] as? String == "Cut CI build times across every product target")
        #expect(firstOverlap["count"] as? Int == 2)
        #expect(
            firstOverlap["tags"] as? [String] == ["Kubernetes", "Swift"],
            "the overlapping primary names, sorted")
        for other in achievements.dropFirst() {
            let overlap = try #require(other["overlap"] as? [String: Any])
            #expect(overlap["count"] as? Int == 0, "a zero-overlap point still carries the annotation")
            #expect(overlap["tags"] as? [String] == [], "empty, never absent — absence would read as not computed")
        }
        let projects = try #require(profileDict["projects"] as? [[String: Any]])
        let ladderProject = try #require(projects.first { $0["name"] as? String == "Ladder" })
        #expect((try #require(ladderProject["overlap"] as? [String: Any]))["count"] as? Int == 1)
        let beacon = try #require(projects.first { $0["name"] as? String == "Beacon" })
        #expect((try #require(beacon["overlap"] as? [String: Any]))["count"] as? Int == 0)
    }

    @Test("[TAILOR-52] the tailor run's payload is annotated against the confirmed Match")
    func tailorRunPayloadCarriesConfirmedOverlap() async throws {
        let (profileStore, application) = try makeWorld()
        let service = FixtureIntelligenceService(
            returning: [try fixtureData("jd-scan"), try fixtureData("tailor-result")])
        let flow = makeFlow(profileStore: profileStore, application: application, service: service)
        await flow.start()

        await flow.confirmMatchReview()

        let tailorRequest = try #require(await service.recordedRequests.last)
        let profileDict = try decodedProfile(from: tailorRequest.payload)
        let roles = try #require(profileDict["roles"] as? [[String: Any]])
        let achievements = try #require(roles.first?["achievements"] as? [[String: Any]])
        let first = try #require(achievements.first)
        let overlap = try #require(first["overlap"] as? [String: Any])
        #expect(
            overlap["tags"] as? [String] == ["Kubernetes", "Swift"],
            "the annotation is computed against the Match the review confirmed")
    }

    @Test("[TAILOR-53] the tailor payload orders achievements within each role and projects by descending overlap")
    func payloadOrdersPointsByDescendingOverlap() async throws {
        let (profileStore, _) = try makeWorld()
        let ladder = try profileStore.addProject(name: "Ladder", details: "Interview companion")
        try profileStore.tag(ladder, skillNamed: "Swift")
        let beacon = try profileStore.addProject(name: "Beacon", details: "Weather worker")
        try profileStore.tag(beacon, skillNamed: "Leadership")
        let profile = try #require(profileStore.profile)

        let payload = try TailorPayload(
            profile: profile, details: jobDetails, matchedTagNames: ["Leadership"])

        let profileDict = try decodedProfile(from: payload.json)
        let roles = try #require(profileDict["roles"] as? [[String: Any]])
        let achievements = try #require(roles.first?["achievements"] as? [[String: Any]])
        #expect(
            achievements.map { $0["text"] as? String } == [
                "Led incident response for the payments outage",
                "Cut CI build times across every product target",
                "Shipped the offline sync engine",
            ],
            "the Leadership point leads; the tie keeps the Profile's own order — a stable sort")
        #expect(
            achievements.map { $0["id"] as? String } == ["a1", "a2", "a3"],
            "ids are payload-positional and stay stable within this payload")
        #expect(
            payload.achievementsByID["a1"]?.text == "Led incident response for the payments outage",
            "validation resolves the reordered ids")
        let projects = try #require(profileDict["projects"] as? [[String: Any]])
        #expect(
            projects.map { $0["name"] as? String } == ["Beacon", "Ladder"],
            "projects order by descending overlap despite sort order")
    }

    // MARK: - [TAILOR-54/55] the overlap view

    @Test("[TAILOR-54] the tailor review shows each selected point's covered matched Tags")
    func reviewShowsCoveredMatchedTagsPerPoint() async throws {
        let (profileStore, application) = try makeWorld()
        let service = FixtureIntelligenceService(
            returning: [try fixtureData("jd-scan"), try fixtureData("tailor-result")])
        let flow = makeFlow(profileStore: profileStore, application: application, service: service)
        await flow.start()
        await flow.confirmMatchReview()

        let review = try #require(flow.review)
        let first = try #require(review.items.first)
        #expect(first.achievement.text == "Cut CI build times across every product target")
        #expect(
            review.coveredMatchedTags(for: first.achievement) == ["Kubernetes", "Swift"],
            "the matched Tags this point's own Tags cover, by primary name")
        let second = try #require(review.items.last)
        #expect(second.achievement.text == "Led incident response for the payments outage")
        #expect(
            review.coveredMatchedTags(for: second.achievement) == [],
            "a selected point covering nothing shows none — Leadership is not matched")
    }

    @Test("[TAILOR-54] a selected project's covered matched Tags derive from its own Tags")
    func selectedProjectCoverageDerivesFromItsTags() async throws {
        let (profileStore, _) = try makeWorld()
        let project = try profileStore.addProject(
            name: "Trail Mapper", details: "Built tile caching so maps survive without signal.")
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
        let store = TailorStore(
            profileStore: profileStore,
            keyStore: InMemoryAPIKeyStore(key: "sk-test"),
            makeIntelligence: { _ in FixtureIntelligenceService(returning: selectingProject) })

        await store.startRun(jobDetails, matchedTagNames: ["Swift", "Kubernetes"])

        let review = try #require(store.review)
        let selected = try #require(review.selectedProjects.first)
        #expect(review.coveredMatchedTags(for: selected) == ["Swift"])
    }

    @Test("[TAILOR-55] the tailor review lists the matched Tags no selected point covers")
    func reviewListsUncoveredMatchedTags() async throws {
        let (profileStore, application) = try makeWorld()
        let scan = Data(
            #"{"matched": ["Swift", "Kubernetes", "SwiftUI"], "gaps": [], "suggestions": []}"#.utf8)
        let service = FixtureIntelligenceService(
            returning: [scan, try fixtureData("tailor-result")])
        let flow = makeFlow(profileStore: profileStore, application: application, service: service)
        await flow.start()
        await flow.confirmMatchReview()

        let review = try #require(flow.review)
        #expect(
            review.uncoveredMatchedTags == ["SwiftUI"],
            "SwiftUI is matched vocabulary, but its point was not selected — unevidenced")
    }

    @Test("[TAILOR-55] a selection covering every matched Tag leaves nothing to list")
    func fullCoverageLeavesNothingToList() async throws {
        let (profileStore, application) = try makeWorld()
        let service = FixtureIntelligenceService(
            returning: [try fixtureData("jd-scan"), try fixtureData("tailor-result")])
        let flow = makeFlow(profileStore: profileStore, application: application, service: service)
        await flow.start()
        await flow.confirmMatchReview()

        let review = try #require(flow.review)
        #expect(review.uncoveredMatchedTags == [], "the selected CI point covers Swift and Kubernetes")
    }

    // MARK: - [TAILOR-57/58] the content budget in the request

    private func fitRecord(bullets: Int, projects: Int, characters: Int) -> FitMetrics {
        FitMetrics(
            roleCount: 2, bulletCount: bullets, projectCount: projects, skillCount: 8,
            characterCount: characters, compactionStep: 1, stretchFactor: 1.0,
            condensePassRun: false, trimPassCount: 0, trimmedItemCount: 0,
            naturalPageCount: 2, finalPageCount: 2)
    }

    @Test("[TAILOR-57] the tailor request carries the content budget derived from FitMetrics history")
    func tailorRequestCarriesBudgetFromHistory() async throws {
        let (profileStore, application) = try makeWorld()
        let context = try #require(application.modelContext)
        application.fitMetrics = fitRecord(bullets: 12, projects: 3, characters: 5000)
        let earlier = Application(
            company: "Basecamp Digital", roleTitle: "iOS Engineer",
            jobDescription: "Ship iOS features.", status: .draft)
        context.insert(earlier)
        earlier.fitMetrics = fitRecord(bullets: 10, projects: 5, characters: 6200)
        try context.save()

        let service = FixtureIntelligenceService(
            returning: [try fixtureData("jd-scan"), try fixtureData("tailor-result")])
        let flow = makeFlow(profileStore: profileStore, application: application, service: service)
        await flow.start()
        await flow.confirmMatchReview()

        let tailorRequest = try #require(await service.recordedRequests.last)
        let root = try #require(
            try JSONSerialization.jsonObject(with: Data(tailorRequest.payload.utf8)) as? [String: Any])
        let budget = try #require(root["budget"] as? [String: Any], "the aim-for line travels in the payload")
        #expect(budget["bullets"] as? Int == 12, "each field's maximum across every Application's history")
        #expect(budget["projects"] as? Int == 5)
        #expect(budget["characters"] as? Int == 6200)
    }

    @Test("[TAILOR-58] a tailor run with no qualifying FitMetrics history sends no budget")
    func noQualifyingHistorySendsNoBudget() async throws {
        let (profileStore, application) = try makeWorld()
        let context = try #require(application.modelContext)
        // The one export on record needed a trim — it proves nothing fits.
        var trimmed = fitRecord(bullets: 18, projects: 4, characters: 8000)
        trimmed.trimPassCount = 1
        trimmed.trimmedItemCount = 2
        application.fitMetrics = trimmed
        try context.save()

        let service = FixtureIntelligenceService(
            returning: [try fixtureData("jd-scan"), try fixtureData("tailor-result")])
        let flow = makeFlow(profileStore: profileStore, application: application, service: service)
        await flow.start()
        await flow.confirmMatchReview()

        let tailorRequest = try #require(await service.recordedRequests.last)
        let root = try #require(
            try JSONSerialization.jsonObject(with: Data(tailorRequest.payload.utf8)) as? [String: Any])
        #expect(
            root["budget"] == nil,
            "no key, no zeros — the payload reads exactly as one built with no budget at all")
    }

    // MARK: - [TAILOR-45] confirmation gates the tailor run

    @Test("[TAILOR-45] the tailor run starts only after the Match review is confirmed")
    func tailorRunWaitsForConfirmation() async throws {
        let (profileStore, application) = try makeWorld()
        let service = FixtureIntelligenceService(
            returning: [try fixtureData("jd-scan"), try fixtureData("tailor-result")])
        let flow = makeFlow(profileStore: profileStore, application: application, service: service)

        await flow.start()
        #expect(flow.phase == .matchReview)
        #expect(
            await service.recordedRequests.count == 1,
            "however long the flow holds in the review, no tailor prompt is sent")

        await flow.confirmMatchReview()

        #expect(flow.phase == .review, "confirming starts the tailor run")
        let requests = await service.recordedRequests
        #expect(requests.count == 2)
        #expect(
            requests.last?.prompt == (try TailorPrompt.text()),
            "the request after confirmation is the tailor prompt")
        #expect(flow.review != nil, "the run produced a tailor result for review ([TAILOR-1])")
    }
}

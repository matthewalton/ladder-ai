import Foundation
import SwiftData
import Testing

@testable import Ladder

@MainActor
struct MatchSectionTests {
    /// The same world the canned jd-scan fixture speaks to (the
    /// TailorFlowStoreTests shape).
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
        try profileStore.tag(first, skillNamed: "Swift")
        let kubernetes = try profileStore.tag(first, skillNamed: "Kubernetes")
        try profileStore.recordAlias("k8s", on: kubernetes)
        let second = try profileStore.addAchievement(
            to: role, text: "Shipped the offline sync engine")
        try profileStore.tag(second, skillNamed: "SwiftUI")
        let third = try profileStore.addAchievement(
            to: role, text: "Led incident response for the payments outage")
        try profileStore.tag(third, skillNamed: "Leadership")

        let context = ModelContext(profileStore.container)
        let application = Application(
            company: "Summit Labs", roleTitle: "Platform Engineer",
            jobDescription: "Own platform reliability. Kubernetes, CI at scale, incident response.",
            status: .active)
        context.insert(application)
        try context.save()
        return (profileStore, application)
    }

    private func makeModel(
        application: Application,
        service: FixtureIntelligenceService,
        keyStore: any APIKeyStore = InMemoryAPIKeyStore(key: "sk-test")
    ) -> MatchSectionModel {
        MatchSectionModel(
            application: application,
            keyStore: keyStore,
            makeIntelligence: { _ in service })
    }

    private func fixtureData(_ name: String) throws -> Data {
        let url = try #require(
            Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    // MARK: - [PIPEBOARD-43] the summary derives from the persisted Match

    @Test("[PIPEBOARD-43] the application detail shows the Application's Match score with its matched Tags and vocabulary gaps")
    func summaryDerivesFromPersistedMatch() async throws {
        let (profileStore, application) = try makeWorld()
        let context = try #require(application.modelContext)
        let profile = try #require(profileStore.profile)
        let swift = try #require(profile.skills.first { $0.name == "Swift" })
        let kubernetes = try #require(profile.skills.first { $0.name == "Kubernetes" })
        application.match = Match(
            matchedTags: [swift, kubernetes],
            vocabularyGaps: ["GraphQL", "Team leadership"])
        try context.save()

        let summary = try #require(MatchSectionModel.summary(of: application))
        #expect(summary.score == 50, "2 matched, 2 gaps — [TAILOR-41]'s derivation, never stored")
        #expect(Set(summary.matchedTagNames) == ["Swift", "Kubernetes"], "matched Tags by primary name")
        #expect(summary.vocabularyGaps == ["GraphQL", "Team leadership"], "gaps verbatim")
        #expect(summary.scannedAt == application.match?.scannedAt)
    }

    @Test("[PIPEBOARD-43] a Match with no asks shows no score")
    func noAsksMeansNoScore() async throws {
        let (_, application) = try makeWorld()
        let context = try #require(application.modelContext)
        application.match = Match(matchedTags: [], vocabularyGaps: [])
        try context.save()

        let summary = try #require(MatchSectionModel.summary(of: application))
        #expect(summary.score == nil, "no asks means no score — never a fake 100")
        #expect(summary.matchedTagNames.isEmpty)
        #expect(summary.vocabularyGaps.isEmpty)
    }

    // MARK: - [PIPEBOARD-44] the door into the review

    @Test("[PIPEBOARD-44] Scan JD on the application detail presents the Match review for its stored job description")
    func scanPresentsTheMatchReview() async throws {
        let (_, application) = try makeWorld()
        let service = FixtureIntelligenceService(returning: [try fixtureData("jd-scan")])
        let model = makeModel(application: application, service: service)

        await model.scan()

        #expect(model.phase == .review, "the flow holds in the Match review after the scan")
        let review = try #require(model.matchReview)
        #expect(Set(review.matchedTagNames) == ["Swift", "Kubernetes"])
        #expect(review.suggestions.count == 3, "every transient suggestion appears for review")
        let requests = await service.recordedRequests
        #expect(requests.count == 1, "one scan request — nothing else")
        #expect(
            requests.first?.prompt == (try JDScanPrompt.text()),
            "the door's one request is the jd-scan prompt")
        #expect(application.match != nil, "the scan stored the Match ([TAILOR-27])")
    }

    @Test("[PIPEBOARD-44] a repeat Scan JD replaces the Match and presents a fresh review")
    func repeatScanReplacesAndRepresents() async throws {
        let (_, application) = try makeWorld()
        let service = FixtureIntelligenceService(
            returning: [try fixtureData("jd-scan"), try fixtureData("jd-scan")])
        let model = makeModel(application: application, service: service)
        await model.scan()
        model.cancelReview()
        let firstScannedAt = try #require(application.match?.scannedAt)

        await model.scan()

        #expect(model.phase == .review, "the door re-opens the review")
        let scannedAt = try #require(application.match?.scannedAt)
        #expect(scannedAt > firstScannedAt, "the Match tracks the pool — replaced, never reused ([TAILOR-36])")
    }

    // MARK: - [PIPEBOARD-45] the JD-only gate

    @Test("[PIPEBOARD-45] the Match section appears only while the application's trimmed job description is non-empty")
    func sectionGatesOnTheJobDescriptionAlone() {
        #expect(MatchSectionModel.offersMatchSection(jobDescription: "Own platform reliability."))
        #expect(
            !MatchSectionModel.offersMatchSection(jobDescription: ""),
            "no JD, no section — [PIPEBOARD-33]'s remove can empty it")
        #expect(
            !MatchSectionModel.offersMatchSection(jobDescription: "  \n\t "),
            "whitespace-only counts as empty")
    }

    // MARK: - [PIPEBOARD-46] the prompt state

    @Test("[PIPEBOARD-46] a Match-less application's Match section shows the scan prompt")
    func matchlessSectionShowsThePrompt() throws {
        let (_, application) = try makeWorld()

        #expect(application.match == nil, "a pre-Match application ([TAILOR-42]) — every existing row's first view")
        #expect(
            MatchSectionModel.summary(of: application) == nil,
            "nil summary is the prompt state: no score, no Tag lists, no gap rows")
        #expect(
            MatchSectionModel.offersMatchSection(jobDescription: application.jobDescription),
            "the prompt still offers the scan — the door is how the first Match arrives")
    }

    // MARK: - [PIPEBOARD-47] confirm ends at the detail

    @Test("[PIPEBOARD-47] confirming the on-demand Match review sends no tailor request")
    func confirmingSendsNoTailorRequest() async throws {
        let (profileStore, application) = try makeWorld()
        let service = FixtureIntelligenceService(returning: [try fixtureData("jd-scan")])
        let model = makeModel(application: application, service: service)
        await model.scan()
        let review = try #require(model.matchReview)
        for index in review.suggestions.indices {
            review.suggestions[index].isAccepted = true
        }

        model.confirmReview()

        #expect(
            await service.recordedRequests.count == 1,
            "the scan's own request stays the only one — no tailor prompt ever ([TAILOR-44]'s stance)")
        #expect(model.phase == .idle, "the flow ends back at the detail")
        #expect(model.matchReview == nil)
        let fresh = ModelContext(profileStore.container)
        let profile = try #require(try fresh.fetch(FetchDescriptor<Profile>()).first)
        #expect(
            profile.skills.contains { $0.name == "GraphQL" },
            "the accepted mint landed in the pool")
        let summary = try #require(MatchSectionModel.summary(of: application))
        #expect(summary.vocabularyGaps.isEmpty, "both resolved gaps moved into the matched Tags")
        #expect(summary.score == 100, "the score the user watched survives confirmation")
    }

    @Test("[PIPEBOARD-47] cancelling the on-demand review keeps the scanned Match and sends nothing")
    func cancellingKeepsTheScannedMatch() async throws {
        let (profileStore, application) = try makeWorld()
        let service = FixtureIntelligenceService(returning: [try fixtureData("jd-scan")])
        let model = makeModel(application: application, service: service)
        await model.scan()
        let review = try #require(model.matchReview)
        review.suggestions[0].isAccepted = true

        model.cancelReview()

        #expect(model.phase == .idle, "cancel also ends back at the detail")
        #expect(model.matchReview == nil)
        #expect(await service.recordedRequests.count == 1)
        let fresh = ModelContext(profileStore.container)
        let profile = try #require(try fresh.fetch(FetchDescriptor<Profile>()).first)
        #expect(
            !profile.skills.contains { $0.name == "GraphQL" },
            "checked or not, only confirmation writes ([TAILOR-50])")
        let summary = try #require(MatchSectionModel.summary(of: application))
        #expect(
            summary.vocabularyGaps == ["GraphQL", "Team leadership"],
            "the freshly scanned Match stays — the summary shows it")
    }

    // MARK: - [PIPEBOARD-48] failure surfaces with retry

    @Test("[PIPEBOARD-48] a failed on-demand scan shows the failure reason with a retry action")
    func failedScanSurfacesReasonAndRetries() async throws {
        let (_, application) = try makeWorld()
        let invalid = Data(#"{"nonsense": true}"#.utf8)
        let service = FixtureIntelligenceService(
            returning: [invalid, invalid, try fixtureData("jd-scan")])
        let model = makeModel(application: application, service: service)

        await model.scan()

        #expect(
            model.phase == .failed(.resultInvalid(reason: "the response has no matched array")),
            "the reason surfaces in the section")
        #expect(
            await service.recordedRequests.count == 2,
            "the scan and its single repair ([TAILOR-31]) — nothing more")
        #expect(application.match == nil, "a failed scan leaves the Match as it was ([TAILOR-32])")

        // The third canned response is valid, so retry lands in the review.
        await model.retry()
        #expect(model.phase == .review, "retry lands in the Match review")
        #expect(await service.recordedRequests.count == 3, "retry scanned again")
    }

    @Test("[PIPEBOARD-48] a missing API key fails the scan before any request")
    func missingKeyFailsBeforeAnyRequest() async throws {
        let (_, application) = try makeWorld()
        let service = FixtureIntelligenceService(returning: [try fixtureData("jd-scan")])
        let model = makeModel(
            application: application, service: service,
            keyStore: InMemoryAPIKeyStore(key: nil))

        await model.scan()

        #expect(model.phase == .failed(.apiKeyRequired), "the [TAILOR-34] refusal, surfaced here")
        #expect(await service.recordedRequests.isEmpty, "refused before any service call")
    }
}

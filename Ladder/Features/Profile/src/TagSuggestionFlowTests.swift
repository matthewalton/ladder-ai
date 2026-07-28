import Foundation
import SwiftData
import Testing

@testable import Ladder

@MainActor
struct TagSuggestionFlowTests {
    private func makeProfileStore() throws -> ProfileStore {
        let store = try ProfileStore(container: ProfileStore.container(inMemory: true))
        try store.load()
        return store
    }

    /// A profile with one cluster-flavoured point and a pool of Kubernetes
    /// (no alias yet) — the shape the canned fixture response speaks to.
    private func makePopulatedProfile() throws -> (ProfileStore, Achievement) {
        let profileStore = try makeProfileStore()
        try profileStore.createProfile(name: "Alex Climber", headline: "")
        let role = try profileStore.addRole(company: "Acme", title: "Engineer", start: .now, end: nil)
        let achievement = try profileStore.addAchievement(
            to: role, text: "Kept the production cluster healthy through a region failover")
        try profileStore.updateAchievementTitle(achievement, to: "Owned the cluster")
        try profileStore.updateAchievementDetails(
            achievement, impactMetric: "99.99% uptime", strengthNotes: "Full STAR story")
        _ = try profileStore.tag(achievement, skillNamed: "Kubernetes")
        return (profileStore, achievement)
    }

    private func makeSuggestionStore(
        profileStore: ProfileStore,
        service: FixtureIntelligenceService,
        keyStore: any APIKeyStore = InMemoryAPIKeyStore(key: "test-key")
    ) -> TagSuggestionStore {
        TagSuggestionStore(
            profileStore: profileStore,
            keyStore: keyStore,
            makeIntelligence: { _ in service }
        )
    }

    @Test("[PROFILE-31] a Tag suggestion request carries the versioned tags prompt and the pool vocabulary")
    func requestCarriesPromptAndVocabulary() async throws {
        let (profileStore, achievement) = try makePopulatedProfile()
        let kubernetes = try #require(profileStore.profile?.skills.first)
        try profileStore.recordAlias("k8s", on: kubernetes)

        let service = FixtureIntelligenceService.tagSuggestionsFixture()
        let store = makeSuggestionStore(profileStore: profileStore, service: service)

        await store.requestSuggestions(for: achievement)

        let request = try #require(await service.recordedRequests.first)
        #expect(
            request.prompt == (try TagsPrompt.text()),
            "the prompt travels verbatim from the versioned Prompts/tags.md")
        #expect(request.payload.contains("Kubernetes"), "the vocabulary carries primary names")
        #expect(request.payload.contains("k8s"), "…and Aliases")
        #expect(
            request.payload.contains("region failover"),
            "…and the point's own evidence fields")
        #expect(request.payload.contains("99.99% uptime"))
        #expect(request.payload.contains("Full STAR story"))
    }

    @Test("[PROFILE-32] a Tag suggestion run proposes attach, mint and alias changes for review")
    func runProposesAllThreeKindsForReview() async throws {
        let (profileStore, achievement) = try makePopulatedProfile()
        let service = FixtureIntelligenceService.tagSuggestionsFixture()
        let store = makeSuggestionStore(profileStore: profileStore, service: service)

        await store.requestSuggestions(for: achievement)

        #expect(store.phase == .review)
        #expect(store.proposals.count == 3, "the canned fixture carries all three kinds")
        #expect(store.proposals.first?.change == .attach(tagName: "Kubernetes"))
        #expect(store.proposals.dropFirst().first?.change == .mint(name: "Incident response"))
        #expect(store.proposals.last?.change == .alias("k8s", onTagNamed: "Kubernetes"))

        #expect(profileStore.profile?.skills.count == 1)
        #expect(achievement.skills.map(\.name) == ["Kubernetes"])
        let kubernetes = try #require(profileStore.profile?.skills.first)
        #expect(kubernetes.aliases == [])
    }

    @Test("[PROFILE-33] confirming an attach suggestion links the existing Tag to the point")
    func confirmingAttachLinksExistingTag() async throws {
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }

        do {
            let profileStore = try ProfileStore(container: ProfileStore.container(at: url))
            try profileStore.load()
            try profileStore.createProfile(name: "Alex Climber", headline: "")
            let role = try profileStore.addRole(company: "Acme", title: "Engineer", start: .now, end: nil)
            let target = try profileStore.addAchievement(
                to: role, text: "Kept the production cluster healthy through a region failover")
            let other = try profileStore.addAchievement(to: role, text: "Also ran the infra")
            let kubernetes = try profileStore.tag(other, skillNamed: "Kubernetes")

            let service = FixtureIntelligenceService.tagSuggestionsFixture()
            let store = makeSuggestionStore(profileStore: profileStore, service: service)
            await store.requestSuggestions(for: target)
            let attach = try #require(store.proposals.first)
            #expect(attach.change == .attach(tagName: "Kubernetes"))

            try store.confirm(attach)

            #expect(target.skills.contains { $0 === kubernetes }, "the one shared Tag is linked")
            #expect(profileStore.profile?.skills.count == 1, "no new Tag, no rename — a link and nothing else")
        }

        let reopened = try ProfileStore(container: ProfileStore.container(at: url))
        try reopened.load()
        let profile = try #require(reopened.profile)
        let target = try #require(
            profile.roles.first?.achievements.first { $0.text.contains("region failover") })
        #expect(target.skills.map(\.name) == ["Kubernetes"], "the link survived the reopen")
    }

    @Test("[PROFILE-34] confirming a mint suggestion creates the Tag and links it to the point")
    func confirmingMintCreatesAndLinksTheTag() async throws {
        let (profileStore, achievement) = try makePopulatedProfile()
        let service = FixtureIntelligenceService.tagSuggestionsFixture()
        let store = makeSuggestionStore(profileStore: profileStore, service: service)
        await store.requestSuggestions(for: achievement)
        let mint = try #require(store.proposals.dropFirst().first)
        #expect(mint.change == .mint(name: "Incident response"))

        try store.confirm(mint)

        let minted = try #require(profileStore.profile?.skills.first { $0.name == "Incident response" })
        #expect(minted.name == "Incident response", "the proposed name is the curated casing")
        #expect(achievement.skills.contains { $0 === minted })
        #expect(profileStore.profile?.skills.count == 2)
    }

    @Test("[PROFILE-34] a mint whose name matches the pool links the existing Tag instead")
    func staleMintResolvesToTheExistingTag() async throws {
        let (profileStore, achievement) = try makePopulatedProfile()
        let role = try #require(profileStore.profile?.roles.first)
        let other = try profileStore.addAchievement(to: role, text: "Owned the pager")
        let existing = try profileStore.tag(other, skillNamed: "incident response")

        let service = FixtureIntelligenceService.tagSuggestionsFixture()
        let store = makeSuggestionStore(profileStore: profileStore, service: service)
        await store.requestSuggestions(for: achievement)
        let mint = try #require(store.proposals.dropFirst().first)

        try store.confirm(mint)

        #expect(
            achievement.skills.contains { $0 === existing },
            "the model's view of the pool may be stale, the store's never is")
        #expect(existing.name == "incident response", "the first-entered casing survives")
        #expect(profileStore.profile?.skills.count == 2, "no duplicate Tag was minted")
    }

    @Test("[PROFILE-35] confirming an alias suggestion records the Alias on its Tag")
    func confirmingAliasRecordsIt() async throws {
        let (profileStore, achievement) = try makePopulatedProfile()
        let service = FixtureIntelligenceService.tagSuggestionsFixture()
        let store = makeSuggestionStore(profileStore: profileStore, service: service)
        await store.requestSuggestions(for: achievement)
        let alias = try #require(store.proposals.last)
        #expect(alias.change == .alias("k8s", onTagNamed: "Kubernetes"))

        try store.confirm(alias)

        let kubernetes = try #require(profileStore.profile?.skills.first { $0.name == "Kubernetes" })
        #expect(kubernetes.aliases == ["k8s"], "recorded through the [PROFILE-26] pathway")
    }

    @Test("[PROFILE-35] a colliding alias suggestion is refused exactly as a manual one")
    func collidingAliasSuggestionIsRefused() async throws {
        let (profileStore, achievement) = try makePopulatedProfile()
        let kubernetes = try #require(profileStore.profile?.skills.first)
        try profileStore.recordAlias("k8s", on: kubernetes)

        let service = FixtureIntelligenceService.tagSuggestionsFixture()
        let store = makeSuggestionStore(profileStore: profileStore, service: service)
        await store.requestSuggestions(for: achievement)
        let alias = try #require(store.proposals.last)

        #expect(throws: ProfileStoreError.aliasAlreadyInUse) {
            try store.confirm(alias)
        }
        #expect(kubernetes.aliases == ["k8s"], "the pool is unchanged after the refusal")
    }

    @Test("[PROFILE-36] a declined Tag suggestion leaves the pool and the point's Tags unchanged")
    func decliningLeavesEverythingUnchanged() async throws {
        let (profileStore, achievement) = try makePopulatedProfile()
        let service = FixtureIntelligenceService.tagSuggestionsFixture()
        let store = makeSuggestionStore(profileStore: profileStore, service: service)
        await store.requestSuggestions(for: achievement)

        for proposal in store.proposals {
            store.decline(proposal)
        }

        #expect(store.proposals.isEmpty)
        #expect(profileStore.profile?.skills.count == 1, "nothing lands without confirmation")
        #expect(achievement.skills.map(\.name) == ["Kubernetes"])
        #expect(profileStore.profile?.skills.first?.aliases == [])
    }

    @Test("[PROFILE-36] confirming one proposal and declining the rest lands exactly the confirmed one")
    func partialConfirmationLandsExactlyTheConfirmedChange() async throws {
        let (profileStore, achievement) = try makePopulatedProfile()
        let service = FixtureIntelligenceService.tagSuggestionsFixture()
        let store = makeSuggestionStore(profileStore: profileStore, service: service)
        await store.requestSuggestions(for: achievement)

        let mint = try #require(store.proposals.dropFirst().first)
        try store.confirm(mint)
        for proposal in store.proposals {
            store.decline(proposal)
        }

        let names = Set((profileStore.profile?.skills ?? []).map(\.name))
        #expect(names == ["Kubernetes", "Incident response"], "only the confirmed mint landed")
        #expect(
            profileStore.profile?.skills.first { $0.name == "Kubernetes" }?.aliases == [],
            "the declined alias never landed")
    }

    @Test("[PROFILE-37] requesting Tag suggestions with no API key stored is refused")
    func noStoredKeyIsRefusedBeforeAnyServiceCall() async throws {
        let (profileStore, achievement) = try makePopulatedProfile()
        let service = FixtureIntelligenceService.tagSuggestionsFixture()
        let store = makeSuggestionStore(
            profileStore: profileStore, service: service, keyStore: InMemoryAPIKeyStore())

        await store.requestSuggestions(for: achievement)

        #expect(store.phase == .failed(.apiKeyRequired))
        #expect(store.proposals.isEmpty)
        #expect(
            await service.recordedRequests.isEmpty,
            "refused before any service call — never a fixture fallback")
    }

    @Test("[PROFILE-38] the suggestion run creates its live service with the stored API key")
    func runCreatesItsServiceWithTheStoredKey() async throws {
        let (profileStore, achievement) = try makePopulatedProfile()
        let service = FixtureIntelligenceService.tagSuggestionsFixture()
        let receivedKey = SuggestionKeyBox()
        let store = TagSuggestionStore(
            profileStore: profileStore,
            keyStore: InMemoryAPIKeyStore(key: "sk-ladder-tags-test"),
            makeIntelligence: { key in
                receivedKey.value = key
                return service
            }
        )

        await store.requestSuggestions(for: achievement)

        #expect(receivedKey.value == "sk-ladder-tags-test", "the factory receives exactly the stored key")
        #expect(store.phase == .review)
    }

    @Test("[PROFILE-39] a suggestion response failing validation fails the run with the reason")
    func invalidResponseFailsWithItsReason() async throws {
        let (profileStore, achievement) = try makePopulatedProfile()

        let garbage = makeSuggestionStore(
            profileStore: profileStore,
            service: FixtureIntelligenceService(returning: Data("no json here".utf8)))
        await garbage.requestSuggestions(for: achievement)
        #expect(garbage.phase == .failed(.responseInvalid(reason: "the response was not valid JSON")))

        let missingPart = makeSuggestionStore(
            profileStore: profileStore,
            service: FixtureIntelligenceService(
                returning: Data(#"{"suggestions":[{"kind":"mint"}]}"#.utf8)))
        await missingPart.requestSuggestions(for: achievement)
        #expect(
            missingPart.phase
                == .failed(.responseInvalid(reason: "suggestion 1 (mint) is missing 'name'")))

        let unknownKind = makeSuggestionStore(
            profileStore: profileStore,
            service: FixtureIntelligenceService(
                returning: Data(#"{"suggestions":[{"kind":"merge","tag":"Swift"}]}"#.utf8)))
        await unknownKind.requestSuggestions(for: achievement)
        #expect(
            unknownKind.phase
                == .failed(.responseInvalid(reason: "suggestion 1 has unknown kind 'merge'")))

        #expect(unknownKind.proposals.isEmpty)
        #expect(profileStore.profile?.skills.count == 1)
    }

    @Test("[PROFILE-39] a fenced-but-valid response reaches review")
    func fencedResponseReachesReview() async throws {
        let (profileStore, achievement) = try makePopulatedProfile()
        let bundle = Bundle.main
        let url = try #require(
            bundle.url(forResource: "tag-suggestions", withExtension: "json", subdirectory: "Fixtures"))
        let bare = try String(contentsOf: url, encoding: .utf8)
        let fenced = Data("```json\n\(bare)\n```".utf8)

        let store = makeSuggestionStore(
            profileStore: profileStore,
            service: FixtureIntelligenceService(returning: fenced))
        await store.requestSuggestions(for: achievement)

        #expect(store.phase == .review, "the fence is presentation, not content ([CVIMPORT-18])")
        #expect(store.proposals.count == 3)
    }

    @Test("[PROFILE-39] a truncated response carries its own reason via the shared service")
    func truncatedResponseCarriesItsOwnReason() async throws {
        let (profileStore, achievement) = try makePopulatedProfile()
        let store = TagSuggestionStore(
            profileStore: profileStore,
            keyStore: InMemoryAPIKeyStore(key: "test-key"),
            makeIntelligence: { _ in
                ThrowingSuggestionService(error: .truncated)
            }
        )

        await store.requestSuggestions(for: achievement)

        #expect(store.phase == .failed(.responseTruncated), "a length problem, not a transport one")
    }

    @Test("[PROFILE-31] a Project's suggestion request carries its own evidence")
    func projectRequestCarriesItsEvidence() async throws {
        let (profileStore, _) = try makePopulatedProfile()
        let project = try profileStore.addProject(
            name: "Trail Mapper",
            summary: "Offline-first hiking maps",
            details: "Built tile caching so a week's maps survive without signal.")

        let service = FixtureIntelligenceService.tagSuggestionsFixture()
        let store = makeSuggestionStore(profileStore: profileStore, service: service)

        await store.requestSuggestions(for: project)

        let request = try #require(await service.recordedRequests.first)
        #expect(request.payload.contains("Trail Mapper"))
        #expect(request.payload.contains("Offline-first hiking maps"))
        #expect(request.payload.contains("tile caching"))
        #expect(request.payload.contains("Kubernetes"), "the vocabulary travels for a Project too")
    }
}

private struct ThrowingSuggestionService: IntelligenceService {
    var error: AnthropicIntelligenceService.LiveServiceError

    func complete(_ request: IntelligenceRequest) async throws -> Data {
        throw error
    }
}

/// The `makeIntelligence` factory runs on the main actor inside the store.
@MainActor
private final class SuggestionKeyBox {
    var value: String?
}

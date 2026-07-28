import Foundation
import SwiftData
import Testing

@testable import Ladder

@MainActor
struct CVEditSetTests {
    @Test("[CVEXPORT-38] coverage splits the Match's matched Tags into those the selection carries and those nothing carries")
    func coverageSplitsMatchedTags() async throws {
        let harness = try await CVPreviewFixture.harness()

        let coverage = harness.model.coverage

        #expect(coverage.carried == ["CI/CD", "SQL", "Swift"])
        #expect(coverage.uncovered == ["Kubernetes"], "nothing selected carries it")
        #expect(
            coverage.matchedCount == CVPreviewFixture.matchedTagNames.count,
            "the partition is total — every matched Tag lands on exactly one side")
    }

    @Test("[CVEXPORT-38] adding a point tagged with an uncovered matched Tag closes it")
    func addingATaggedPointClosesTheGap() async throws {
        let harness = try await CVPreviewFixture.harness()
        let kubernetesPoint = try CVPreviewFixture.achievement(
            "Shipped the offline sync engine", in: harness.profileStore)

        harness.model.setSelected(kubernetesPoint, true)

        #expect(harness.model.coverage.carried.count == 4)
        #expect(harness.model.coverage.uncovered.isEmpty)
    }

    @Test("[CVEXPORT-38] a Tag on an unselected point counts for nothing")
    func unselectedPointsCountForNothing() async throws {
        let harness = try await CVPreviewFixture.harness()
        let sqlPoint = try CVPreviewFixture.achievement(
            "Built the reporting stack", in: harness.profileStore)

        harness.model.setSelected(sqlPoint, false)

        #expect(!harness.model.coverage.carried.contains("SQL"))
        #expect(harness.model.coverage.uncovered.contains("SQL"))
    }

    @Test("[CVEXPORT-38] a Tag the Match never matched counts for nothing")
    func unmatchedTagsCountForNothing() async throws {
        let harness = try await CVPreviewFixture.harness()

        let coverage = harness.model.coverage

        #expect(
            !coverage.carried.contains("Mapping"),
            "Trail Mapper carries it, but coverage measures this CV against this Match")
        #expect(!coverage.uncovered.contains("Mapping"))
    }

    @Test("[CVEXPORT-38] coverage resolves a matched Tag through an Alias")
    func coverageResolvesThroughAliases() async throws {
        let harness = try await CVPreviewFixture.harness()
        let profile = try #require(harness.profileStore.profile)
        let kubernetes = try #require(profile.skills.first(where: { $0.name == "Kubernetes" }))
        try harness.profileStore.recordAlias("k8s", on: kubernetes)
        let kubernetesPoint = try CVPreviewFixture.achievement(
            "Shipped the offline sync engine", in: harness.profileStore)
        harness.model.setSelected(kubernetesPoint, true)

        let coverage = harness.model.edits.coverage(
            profile: profile, matchedTagNames: ["k8s"])

        #expect(coverage.carried == ["k8s"], "case-insensitive, through primary names and Aliases")
        #expect(coverage.uncovered.isEmpty)
    }

    @Test("[CVEXPORT-38] a point in a removed role carries nothing")
    func removedRolesCarryNothing() async throws {
        let harness = try await CVPreviewFixture.harness()
        let globex = try CVPreviewFixture.role("Globex", in: harness.profileStore)

        harness.model.setRemoved(globex, true)

        #expect(harness.model.coverage.uncovered.contains("SQL"), "it is not on the CV any more")
    }

    @Test("[CVEXPORT-39] when the selection changes, coverage recomputes without a service request")
    func coverageRecomputesOffline() async throws {
        let service = FixtureIntelligenceService(returning: Data("{}".utf8))
        let harness = try await CVPreviewFixture.harness(
            rescorePass: RelevanceRescorePass(service: service))
        let profile = try #require(harness.profileStore.profile)
        let sync = try CVPreviewFixture.achievement(
            "Shipped the offline sync engine", in: harness.profileStore)
        let reporting = try CVPreviewFixture.achievement(
            "Built the reporting stack", in: harness.profileStore)
        let mapper = try CVPreviewFixture.project("Trail Mapper", in: harness.profileStore)

        for edit in [
            { harness.model.setSelected(sync, true) },
            { harness.model.setSelected(reporting, false) },
            { harness.model.setSelected(mapper, false) },
            { harness.model.setSelected(reporting, true) },
            { harness.model.setSelected(sync, false) },
        ] {
            edit()
            #expect(
                harness.model.coverage
                    == harness.model.edits.coverage(
                        profile: profile, matchedTagNames: CVPreviewFixture.matchedTagNames),
                "every reading matches a fresh computation over that selection")
        }

        #expect(await service.recordedRequests.isEmpty, "deterministic and offline, every toggle")
    }

    @Test("[CVEXPORT-40] editing the selection in the preview leaves the Match score unchanged")
    func editingLeavesTheMatchScoreUnchanged() async throws {
        let harness = try await CVPreviewFixture.harness()
        let profile = try #require(harness.profileStore.profile)
        let application = try harness.application
        let match = Match(
            matchedTags: Array(profile.skills.prefix(3)),
            vocabularyGaps: ["Terraform"],
            scannedAt: Date(timeIntervalSince1970: 1_770_000_000)
        )
        application.match = match
        try #require(application.modelContext).save()
        let before = try #require(match.score)
        let coverageBefore = harness.model.coverage

        let sync = try CVPreviewFixture.achievement(
            "Shipped the offline sync engine", in: harness.profileStore)
        let reporting = try CVPreviewFixture.achievement(
            "Built the reporting stack", in: harness.profileStore)
        harness.model.setSelected(sync, true)
        harness.model.setSelected(reporting, false)
        harness.model.reword(sync, to: "Shipped offline sync across every client")

        #expect(try harness.application.match?.score == before,
                "the Match scores the Profile against the JD, never this CV")
        #expect(harness.model.coverage != coverageBefore,
                "the number that responds to editing is coverage")
    }
}

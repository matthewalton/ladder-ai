import Foundation
import Testing

@testable import Ladder

@MainActor
struct RelevanceRescoreTests {
    /// The preview numbers its points `s0…` in render order: role bullets
    /// newest-role-first, then the selected projects.
    private static func response(_ ids: [String]) -> Data {
        let entries = ids.map {
            #""\#($0)": {"tech": 2, "domain": 2, "seniority": 2, "impact": 2}"#
        }
        return Data(#"{"relevance": {\#(entries.joined(separator: ","))}}"#.utf8)
    }

    @Test("[CVEXPORT-55] a re-score refreshes the relevance stats over the edited selection in one request")
    func rescoreRefreshesInOneRequest() async throws {
        let service = FixtureIntelligenceService(returning: Self.response(["s0", "s1", "s2"]))
        let harness = try await CVPreviewFixture.harness(
            rescorePass: RelevanceRescorePass(service: service))
        let added = try CVPreviewFixture.achievement(
            "Shipped the offline sync engine", in: harness.profileStore)
        let dropped = try CVPreviewFixture.achievement(
            "Built the reporting stack", in: harness.profileStore)
        harness.model.setSelected(added, true)
        harness.model.setSelected(dropped, false)

        await harness.model.rescore()

        let requests = await service.recordedRequests
        #expect(requests.count == 1, "one pass, on demand — never per keystroke")
        let payload = try #require(requests.first).payload
        #expect(payload.contains("Drove CI build times down across every product target"))
        #expect(payload.contains("Shipped the offline sync engine"), "every currently selected point")
        #expect(payload.contains("Trail Mapper"))
        #expect(
            !payload.contains("Built the analytics reporting stack from scratch"),
            "and nothing the user unticked")

        #expect(harness.model.rescoreFailure == nil)
        let refreshed = RelevanceStats(tech: 2, domain: 2, seniority: 2, impact: 2)
        #expect(harness.model.relevanceStats(for: added) == refreshed)
        #expect(
            harness.model.relevanceStats(for: dropped) == nil,
            "the returned stats replace the whole set rather than merging into it")
    }

    @Test("[CVEXPORT-55] the prompt sent is the versioned rescore prompt file")
    func rescoreSendsTheVersionedPrompt() async throws {
        let service = FixtureIntelligenceService(returning: Self.response(["s0", "s1", "s2"]))
        let harness = try await CVPreviewFixture.harness(
            rescorePass: RelevanceRescorePass(service: service))

        await harness.model.rescore()

        let requests = await service.recordedRequests
        #expect(try #require(requests.first).prompt == RescorePrompt.text())
    }

    @Test("[CVEXPORT-56] a point added in the preview reads as unscored until a re-score runs")
    func addedPointIsUnscoredUntilRescored() async throws {
        let service = FixtureIntelligenceService(returning: Self.response(["s0", "s1", "s2", "s3"]))
        let harness = try await CVPreviewFixture.harness(
            rescorePass: RelevanceRescorePass(service: service))
        let added = try CVPreviewFixture.achievement(
            "Shipped the offline sync engine", in: harness.profileStore)
        let scored = try CVPreviewFixture.achievement(
            "Cut CI build times across every product target", in: harness.profileStore)

        harness.model.setSelected(added, true)

        #expect(
            harness.model.relevanceStats(for: added) == nil,
            "unscored is a state, never a zero")
        #expect(
            harness.model.relevanceStats(for: scored)
                == RelevanceStats(tech: 5, domain: 4, seniority: 3, impact: 4),
            "the tailor's own judgments are untouched")

        await harness.model.rescore()

        #expect(harness.model.relevanceStats(for: added) != nil, "until a re-score runs")
    }

    @Test("[CVEXPORT-57] a failed re-score leaves the existing relevance stats and the composed CV unchanged")
    func failedRescoreChangesNothing() async throws {
        let harness = try await CVPreviewFixture.harness(
            rescorePass: RelevanceRescorePass(service: ThrowingRescoreService()))
        let added = try CVPreviewFixture.achievement(
            "Shipped the offline sync engine", in: harness.profileStore)
        harness.model.setSelected(added, true)
        let scored = try CVPreviewFixture.achievement(
            "Cut CI build times across every product target", in: harness.profileStore)
        let stats = harness.model.relevanceStats(for: scored)
        let pdfData = harness.model.pdfData
        let pageCount = harness.model.pageCount
        let coverage = harness.model.coverage

        await harness.model.rescore()

        #expect(harness.model.relevanceStats(for: scored) == stats, "nothing is half-applied")
        #expect(harness.model.relevanceStats(for: added) == nil, "an unscored point stays unscored")
        #expect(harness.model.pdfData == pdfData)
        #expect(harness.model.pageCount == pageCount)
        #expect(harness.model.coverage == coverage)
        #expect(
            harness.model.rescoreFailure != nil,
            "the failure surfaces as a message the user can retry from")
    }

    @Test("[CVEXPORT-57] a response still invalid after the single repair fails the re-score")
    func invalidResponseAfterRepairFails() async throws {
        let service = FixtureIntelligenceService(returning: Self.response(["s0"]))
        let harness = try await CVPreviewFixture.harness(
            rescorePass: RelevanceRescorePass(service: service))
        let stats = harness.model.relevance

        await harness.model.rescore()

        #expect(await service.recordedRequests.count == 2, "exactly one repair, never a second")
        #expect(harness.model.relevance == stats)
        #expect(harness.model.rescoreFailure != nil)
    }
}

private struct ThrowingRescoreService: IntelligenceService {
    func complete(_ request: IntelligenceRequest) async throws -> Data {
        throw CocoaError(.fileNoSuchFile)
    }
}

import Foundation
import Testing

@testable import Ladder

/// The condense and trim passes (decisions/0010) — tailor-owned service
/// calls the cv-export fit loop invokes. No network anywhere.
@MainActor
struct FitPassTests {
    private var items: [FitPassItem] {
        [
            FitPassItem(id: "b1", text: "Drove CI build times down across every product target, tightening the platform feedback loop for every engineer"),
            FitPassItem(id: "b2", text: "Shipped the offline sync engine with zero data-loss reports across twelve months in production"),
            FitPassItem(id: "b3", text: "Led cross-team incident response for a critical payments outage"),
        ]
    }

    private var condensedJSON: Data {
        Data("""
        {
          "items": [
            {"id": "b1", "text": "Drove CI build times down across every target"},
            {"id": "b2", "text": "Shipped the offline sync engine, zero data loss in a year"},
            {"id": "b3", "text": "Led incident response for a payments outage"}
          ]
        }
        """.utf8)
    }

    @Test("[TAILOR-25] a condense pass returns the same selection with shortened bullet texts")
    func condenseKeepsSelectionAndShortensTexts() async throws {
        let service = FixtureIntelligenceService(returning: condensedJSON)
        let runner = FitPassRunner(service: service)

        let condensed = try await runner.condense(items)

        #expect(condensed.map(\.id) == ["b1", "b2", "b3"], "the selection is identical")
        #expect(condensed.map(\.text) == [
            "Drove CI build times down across every target",
            "Shipped the offline sync engine, zero data loss in a year",
            "Led incident response for a payments outage",
        ])
        // The versioned prompt travels with the request; the payload carries
        // the current texts.
        let request = try #require(await service.recordedRequests.first)
        #expect(request.prompt == (try FitPassPrompts.condense()))
        #expect(request.payload.contains("tightening the platform feedback loop"))
    }

    @Test("[TAILOR-25] a condense response changing the selection triggers exactly one repair request")
    func condenseSelectionChangeFeedsRepair() async throws {
        let dropped = Data("""
        {
          "items": [
            {"id": "b1", "text": "Drove CI build times down"}
          ]
        }
        """.utf8)
        let service = FixtureIntelligenceService(returning: [dropped, condensedJSON])
        let runner = FitPassRunner(service: service)

        let condensed = try await runner.condense(items)

        #expect(await service.recordedRequests.count == 2, "one repair, no more")
        #expect(condensed.map(\.id) == ["b1", "b2", "b3"])
    }

    @Test("[TAILOR-25] a condense repair that still changes the selection fails with the reason")
    func condenseRepairFailureSurfacesReason() async throws {
        let dropped = Data(#"{"items": [{"id": "b1", "text": "Short"}]}"#.utf8)
        let service = FixtureIntelligenceService(returning: [dropped, dropped])
        let runner = FitPassRunner(service: service)

        await #expect(throws: TailorValidationFailure.self) {
            try await runner.condense(self.items)
        }
        #expect(await service.recordedRequests.count == 2, "the run fails after the single repair")
    }

    @Test("[TAILOR-26] a trim pass returns a strict subset of the selection")
    func trimReturnsStrictSubset() async throws {
        let service = FixtureIntelligenceService(returning: Data(#"{"keep": ["b1", "b3"]}"#.utf8))
        let runner = FitPassRunner(service: service)

        let kept = try await runner.trim(items, jobDescription: "Platform reliability role")

        #expect(kept == ["b1", "b3"], "the surviving ids, in payload order")
        let request = try #require(await service.recordedRequests.first)
        #expect(request.prompt == (try FitPassPrompts.trim()))
        #expect(request.payload.contains("Platform reliability role"), "trim judges weakness against the JD")
    }

    @Test("[TAILOR-26] a trim keeping everything or nothing feeds the repair path")
    func trimNonSubsetFeedsRepair() async throws {
        // Keeping the whole selection trims nothing — invalid; the repair
        // returns a genuine strict subset.
        let everything = Data(#"{"keep": ["b1", "b2", "b3"]}"#.utf8)
        let valid = Data(#"{"keep": ["b3"]}"#.utf8)
        let service = FixtureIntelligenceService(returning: [everything, valid])
        let runner = FitPassRunner(service: service)

        let kept = try await runner.trim(items, jobDescription: "JD")

        #expect(await service.recordedRequests.count == 2)
        #expect(kept == ["b3"])

        // An empty keep would drop the whole CV — equally invalid, and a
        // second failure surfaces the reason ([TAILOR-26] body).
        let empty = Data(#"{"keep": []}"#.utf8)
        let failing = FixtureIntelligenceService(returning: [empty, empty])
        let failingRunner = FitPassRunner(service: failing)
        await #expect(throws: TailorValidationFailure.self) {
            try await failingRunner.trim(self.items, jobDescription: "JD")
        }
    }
}

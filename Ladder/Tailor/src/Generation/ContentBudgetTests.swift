import Foundation
import Testing

@testable import Ladder

/// The pure budget helper (decisions/0016) — no store, no service.
struct ContentBudgetTests {
    private func record(
        bullets: Int, projects: Int, characters: Int,
        condensed: Bool = false, trims: Int = 0, finalPages: Int = 2
    ) -> FitMetrics {
        FitMetrics(
            roleCount: 2, bulletCount: bullets, projectCount: projects, skillCount: 8,
            characterCount: characters, compactionStep: 1, stretchFactor: 1.0,
            condensePassRun: condensed, trimPassCount: trims,
            trimmedItemCount: trims == 0 ? 0 : 2, naturalPageCount: 3,
            finalPageCount: finalPages)
    }

    @Test("[TAILOR-56] the content budget takes each field's maximum across the exports that fit without service passes")
    func budgetTakesPerFieldMaximumAcrossQualifiers() {
        let records = [
            record(bullets: 12, projects: 3, characters: 5000),
            record(bullets: 10, projects: 5, characters: 6200),
            record(bullets: 20, projects: 6, characters: 9000, condensed: true),
            record(bullets: 18, projects: 4, characters: 8000, trims: 1),
        ]

        let budget = ContentBudget.from(records)

        #expect(
            budget == ContentBudget(bullets: 12, projects: 5, characters: 6200),
            "per-field maxima from the two qualifiers — the condensed and trimmed exports disqualify")
    }

    @Test("[TAILOR-56] deterministic density work does not disqualify a record")
    func compactionAndStretchAreFree() {
        var compacted = record(bullets: 14, projects: 2, characters: 7000)
        compacted.compactionStep = 3
        compacted.stretchFactor = 1.2

        #expect(
            ContentBudget.from([compacted])
                == ContentBudget(bullets: 14, projects: 2, characters: 7000),
            "compaction steps and underflow stretch are free; only service passes disqualify")
    }

    @Test("[TAILOR-56] no qualifying record means no budget")
    func noQualifiersMeansNoBudget() {
        #expect(ContentBudget.from([]) == nil, "an empty history has proven nothing")
        let onlyServicePassed = [
            record(bullets: 20, projects: 6, characters: 9000, condensed: true),
            record(bullets: 18, projects: 4, characters: 8000, trims: 2),
        ]
        #expect(
            ContentBudget.from(onlyServicePassed) == nil,
            "exports that needed condense or trim never raise the budget — nil, not an invented default")
    }
}

import Foundation

/// The advisory volume target the tailor prompt carries when FitMetrics
/// history has proven what fits (decisions/0016): each field's maximum
/// across exports that fit two pages without service passes. Advisory only —
/// the fit loop stays the enforcement ([CVEXPORT-26..28]).
struct ContentBudget: Equatable, Sendable {
    var bullets: Int
    var projects: Int
    var characters: Int

    /// Nil when no record qualifies — no invented default, no budget line
    /// at all ([TAILOR-58]). Qualifying: fit two pages with no condense or
    /// trim pass; deterministic compaction and stretch are free
    /// ([TAILOR-56]).
    static func from(_ records: [FitMetrics]) -> ContentBudget? {
        let qualifying = records.filter {
            $0.finalPageCount <= 2 && !$0.condensePassRun && $0.trimPassCount == 0
        }
        guard !qualifying.isEmpty else { return nil }
        return ContentBudget(
            bullets: qualifying.map(\.bulletCount).max() ?? 0,
            projects: qualifying.map(\.projectCount).max() ?? 0,
            characters: qualifying.map(\.characterCount).max() ?? 0)
    }
}

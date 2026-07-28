import Foundation

struct ContentBudget: Equatable, Sendable {
    var bullets: Int
    var projects: Int
    var characters: Int

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

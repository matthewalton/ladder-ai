import Foundation

/// The kind guess (decisions/0005): a keyword map over the lowercased event
/// title, first hit in priority order — multi-word kinds outrank single-word
/// ones ("system design screen" → systemDesign). No hit → nil, never a
/// default ([CALSYNC-16]); the guess only ever pre-selects.
enum StageKindGuesser {
    /// Priority order is the decisions/0005 table, top to bottom.
    private static let keywordMap: [(keywords: [String], kind: StageKind)] = [
        (["system design", "architecture"], .systemDesign),
        (["take-home", "take home", "takehome"], .takeHome),
        (["phone screen", "screen", "screening"], .screen),
        (["recruiter", "intro call", "introduction"], .recruiter),
        (["technical", "coding", "pairing", "pair programming"], .technical),
        (["behavioral", "behavioural", "values", "culture"], .behavioral),
        (["final", "onsite", "on-site", "loop"], .final),
        (["offer"], .offer),
    ]

    static func guess(fromTitle title: String) -> StageKind? {
        let lowered = title.lowercased()
        return keywordMap.first { entry in
            entry.keywords.contains { lowered.contains($0) }
        }?.kind
    }
}

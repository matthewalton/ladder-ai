import Foundation

/// First hit in priority order, so multi-word kinds outrank single-word
/// ones ("system design screen" → systemDesign). No hit → nil, never a
/// default; the guess only ever pre-selects.
enum StageKindGuesser {
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

    static var allKeywords: [String] { keywordMap.flatMap(\.keywords) }

    static func guess(fromTitle title: String) -> StageKind? {
        let lowered = title.lowercased()
        return keywordMap.first { entry in
            entry.keywords.contains { lowered.contains($0) }
        }?.kind
    }
}

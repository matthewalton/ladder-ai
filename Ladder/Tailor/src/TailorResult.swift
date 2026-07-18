import Foundation

/// Why a response failed validation — carried into the repair request so the
/// service is told what to fix (SPEC.md [TAILOR-9], decisions/0004).
struct TailorValidationFailure: Error, Equatable {
    var reason: String
}

/// The validated structure the service returns (slice CONTEXT.md: tailor
/// result) — held in memory for review, never persisted (decisions/0001).
struct TailorResult: Equatable, Sendable, Decodable {
    var selections: [TailorSelection]
    var gaps: [String]
    var rationale: String

    /// Validation is schema decode plus the referential check: every
    /// selection must reference an achievement id from the payload
    /// (SPEC.md [TAILOR-8]).
    init(json: Data, validAchievementIDs: Set<String>) throws {
        do {
            self = try JSONDecoder().decode(TailorResult.self, from: json)
        } catch {
            throw TailorValidationFailure(
                reason: "The response did not match the tailor result schema: \(error)"
            )
        }
        let unknown = selections.map(\.achievementID).filter { !validAchievementIDs.contains($0) }
        guard unknown.isEmpty else {
            throw TailorValidationFailure(
                reason: "Selections reference achievement ids not in the payload: \(unknown.joined(separator: ", ")). Use only the ids given."
            )
        }
    }
}

/// One selected achievement with its proposed rephrasing (slice CONTEXT.md).
struct TailorSelection: Equatable, Sendable, Decodable {
    var achievementID: String
    var rephrasing: String
}

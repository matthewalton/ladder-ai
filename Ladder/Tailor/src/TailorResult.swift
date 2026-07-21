import Foundation

/// Carried into the repair request so the service is told what to fix.
struct TailorValidationFailure: Error, Equatable {
    var reason: String
}

struct TailorResult: Equatable, Sendable, Decodable {
    /// The generated CV summary — per application, never stored on the
    /// Profile (decisions/0006).
    var summary: String
    var selections: [TailorSelection]
    var gaps: [String]
    var rationale: String

    init(json: Data, validAchievementIDs: Set<String>) throws {
        // A whole-response fence is presentation, not content — stripped so a
        // formatting quirk never consumes the single repair request.
        let json = FencedJSON.stripped(from: json)
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

struct TailorSelection: Equatable, Sendable, Decodable {
    var achievementID: String
    /// The talking point expanded into one polished CV bullet.
    var bullet: String
}

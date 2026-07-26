import Foundation

/// Carried into the repair request so the service is told what to fix.
struct JourneyValidationFailure: Error, Equatable {
    var reason: String
}

/// The decoded, validated response. Validation is minimal (decisions/0002):
/// the object parses and `narrative` is a non-empty string — free prose has
/// no structure and no references to resolve.
struct JourneyResult: Equatable, Sendable, Decodable {
    var narrative: String

    init(json: Data) throws {
        // A whole-response fence is presentation, not content — stripped so a
        // formatting quirk never consumes the single repair request
        // ([JOURNEY-13]).
        let json = FencedJSON.stripped(from: json)
        do {
            self = try JSONDecoder().decode(JourneyResult.self, from: json)
        } catch {
            throw JourneyValidationFailure(
                reason: "The response did not match the journey result schema: \(error)"
            )
        }
        guard !narrative.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw JourneyValidationFailure(
                reason: "The narrative was empty. Return a non-empty \"narrative\" string."
            )
        }
    }
}

import Foundation

struct JourneyValidationFailure: Error, Equatable {
    var reason: String
}

struct JourneyResult: Equatable, Sendable, Decodable {
    var narrative: String

    init(json: Data) throws {
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

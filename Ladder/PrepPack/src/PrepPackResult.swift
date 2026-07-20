import Foundation

/// Carried into the repair request so the service is told what to fix.
struct PrepPackValidationFailure: Error, Equatable {
    var reason: String
}

/// The decoded, validated response — schema, achievement references, and the
/// technical-kind gate on mock tasks all checked before anything is
/// persisted. No grounding quotes: prep is coaching, not evidence
/// (decisions/0002).
struct PrepPackResult: Equatable, Sendable, Decodable {
    var likelyQuestions: [String]
    var talkingPoints: [PrepPackResultTalkingPoint]
    var companyBrief: String?
    var mockTasks: [MockTask]?

    init(json: Data, achievementCount: Int, mockTasksWanted: Bool) throws {
        // A whole-response fence is presentation, not content — stripped so a
        // formatting quirk never consumes the single repair request
        // ([PREP-18]).
        let json = FencedJSON.stripped(from: json)
        do {
            self = try JSONDecoder().decode(PrepPackResult.self, from: json)
        } catch {
            throw PrepPackValidationFailure(
                reason: "The response did not match the prep result schema: \(error)"
            )
        }
        // Talking points reference payload indices only (decisions/0001).
        let outOfRange = talkingPoints.flatMap(\.achievements).filter {
            !(0..<achievementCount).contains($0)
        }
        guard outOfRange.isEmpty else {
            throw PrepPackValidationFailure(
                reason: """
                    Achievement indices not in the payload's achievement list: \
                    \(outOfRange.map(String.init).joined(separator: ", ")). \
                    Use only the indices given.
                    """
            )
        }
        // Mock tasks belong to technical-type stages only ([PREP-13]).
        guard mockTasksWanted || (mockTasks ?? []).isEmpty else {
            throw PrepPackValidationFailure(
                reason: """
                    Mock tasks were returned for a stage that is not \
                    technical-type. Return "mockTasks": [] for this stage.
                    """
            )
        }
    }
}

struct PrepPackResultTalkingPoint: Equatable, Sendable, Decodable {
    var text: String
    var achievements: [Int]
}

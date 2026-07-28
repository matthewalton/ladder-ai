import Foundation

struct PrepPackValidationFailure: Error, Equatable {
    var reason: String
}

struct PrepPackResult: Equatable, Sendable, Decodable {
    var likelyQuestions: [String]
    var talkingPoints: [PrepPackResultTalkingPoint]
    var companyBrief: String?
    var mockTasks: [MockTask]?

    init(json: Data, achievementCount: Int, mockTasksWanted: Bool) throws {
        let json = FencedJSON.stripped(from: json)
        do {
            self = try JSONDecoder().decode(PrepPackResult.self, from: json)
        } catch {
            throw PrepPackValidationFailure(
                reason: "The response did not match the prep result schema: \(error)"
            )
        }
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

import Foundation

struct DebriefValidationFailure: Error, Equatable {
    var reason: String
}

struct DebriefResult: Equatable, Sendable, Decodable {
    var questions: [DebriefResultQuestion]
    var themes: [GroundedRemark]
    var signals: [GroundedRemark]
    var drills: [String]

    init(json: Data, notesOverview: String, achievementCount: Int) throws {
        let json = FencedJSON.stripped(from: json)
        do {
            self = try JSONDecoder().decode(DebriefResult.self, from: json)
        } catch {
            throw DebriefValidationFailure(
                reason: "The response did not match the debrief result schema: \(error)"
            )
        }
        let quotes =
            questions.map(\.quote)
            + themes.map(\.quote)
            + signals.map(\.quote)
        let fabricated = quotes.filter { !notesOverview.contains($0) }
        guard fabricated.isEmpty else {
            throw DebriefValidationFailure(
                reason: """
                    Quotes not found in the notes overview: \
                    \(fabricated.map { "\"\($0)\"" }.joined(separator: ", ")). \
                    Every quote must be copied verbatim from the notes overview.
                    """
            )
        }
        let outOfRange = questions.flatMap(\.missedAmmo).filter {
            !(0..<achievementCount).contains($0)
        }
        guard outOfRange.isEmpty else {
            throw DebriefValidationFailure(
                reason: """
                    Missed-ammo indices not in the payload's achievement list: \
                    \(outOfRange.map(String.init).joined(separator: ", ")). \
                    Use only the indices given.
                    """
            )
        }
    }
}

struct DebriefResultQuestion: Equatable, Sendable, Decodable {
    var question: String
    var answerSummary: String
    var quality: AnswerQuality
    var quote: String
    var missedAmmo: [Int]
}

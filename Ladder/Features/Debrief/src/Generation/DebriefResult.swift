import Foundation

/// Carried into the repair request so the service is told what to fix.
struct DebriefValidationFailure: Error, Equatable {
    var reason: String
}

/// The decoded, validated response — schema, grounding, and missed-ammo
/// references all checked before anything is persisted.
struct DebriefResult: Equatable, Sendable, Decodable {
    var questions: [DebriefResultQuestion]
    var themes: [GroundedRemark]
    var signals: [GroundedRemark]
    var drills: [String]

    init(json: Data, notesOverview: String, achievementCount: Int) throws {
        // A whole-response fence is presentation, not content — stripped so a
        // formatting quirk never consumes the single repair request
        // ([DEBRIEF-17]).
        let json = FencedJSON.stripped(from: json)
        do {
            self = try JSONDecoder().decode(DebriefResult.self, from: json)
        } catch {
            throw DebriefValidationFailure(
                reason: "The response did not match the debrief result schema: \(error)"
            )
        }
        // Every claim quotes the notes text it is grounded in — an exact
        // substring, no normalisation (decisions/0002).
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
        // Missed ammo references payload indices only (decisions/0001).
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

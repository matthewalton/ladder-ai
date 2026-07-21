import Foundation

/// The full Stage chain in `sortIndex` order — every Stage appears,
/// debriefed or not ([JOURNEY-8]); the JSON must be deterministic.
@MainActor
struct JourneyPayload {
    let json: String

    /// Dates travel as ISO 8601 strings — readable in the prompt, stable
    /// across runs.
    private static let dateFormatter = ISO8601DateFormatter()

    init(application: Application) throws {
        let body = PayloadBody(
            application: PayloadApplication(
                company: application.company,
                roleTitle: application.roleTitle,
                appliedAt: application.appliedAt.map(Self.dateFormatter.string(from:))
            ),
            stages: application.orderedStages.map { stage in
                PayloadStage(
                    kind: stage.kind.rawValue,
                    scheduledAt: stage.scheduledAt.map(Self.dateFormatter.string(from:)),
                    outcome: stage.outcome.rawValue,
                    debrief: stage.debrief.map { debrief in
                        PayloadDebrief(
                            questions: debrief.orderedQuestions.map {
                                PayloadDebriefQuestion(
                                    question: $0.question,
                                    answerSummary: $0.answerSummary,
                                    quality: $0.quality.rawValue
                                )
                            },
                            themes: debrief.themes.map(\.text),
                            signals: debrief.signals.map(\.text),
                            drills: debrief.drills
                        )
                    }
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        json = String(decoding: try encoder.encode(body), as: UTF8.self)
    }
}

private struct PayloadBody: Encodable {
    var application: PayloadApplication
    var stages: [PayloadStage]
}

private struct PayloadApplication: Encodable {
    var company: String
    var roleTitle: String
    var appliedAt: String?
}

private struct PayloadStage: Encodable {
    var kind: String
    var scheduledAt: String?
    var outcome: String
    var debrief: PayloadDebrief?
}

private struct PayloadDebrief: Encodable {
    var questions: [PayloadDebriefQuestion]
    var themes: [String]
    var signals: [String]
    var drills: [String]
}

private struct PayloadDebriefQuestion: Encodable {
    var question: String
    var answerSummary: String
    var quality: String
}

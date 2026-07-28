import Foundation
import SwiftData

enum AnswerQuality: String, Codable, CaseIterable, Sendable {
    case strong
    case adequate
    case weak
}

struct GroundedRemark: Codable, Hashable, Sendable {
    var text: String
    var quote: String
}

@Model
final class Debrief {
    var generatedAt: Date
    var themes: [GroundedRemark]
    var signals: [GroundedRemark]
    var drills: [String]
    var stage: Stage?

    @Relationship(deleteRule: .cascade, inverse: \DebriefQuestion.debrief)
    var questions: [DebriefQuestion]

    /// To-many relationships are unordered; `sortIndex` carries the
    /// service's order.
    var orderedQuestions: [DebriefQuestion] {
        questions.sorted { $0.sortIndex < $1.sortIndex }
    }

    init(
        generatedAt: Date,
        themes: [GroundedRemark] = [],
        signals: [GroundedRemark] = [],
        drills: [String] = []
    ) {
        self.generatedAt = generatedAt
        self.themes = themes
        self.signals = signals
        self.drills = drills
        self.questions = []
    }
}

@Model
final class DebriefQuestion {
    var question: String
    var answerSummary: String
    var quality: AnswerQuality
    var quote: String
    var sortIndex: Int
    var debrief: Debrief?

    var missedAmmo: [Achievement]

    init(
        question: String,
        answerSummary: String,
        quality: AnswerQuality,
        quote: String,
        sortIndex: Int = 0,
        missedAmmo: [Achievement] = []
    ) {
        self.question = question
        self.answerSummary = answerSummary
        self.quality = quality
        self.quote = quote
        self.sortIndex = sortIndex
        self.missedAmmo = missedAmmo
    }
}

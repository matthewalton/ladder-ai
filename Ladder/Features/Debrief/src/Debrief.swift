import Foundation
import SwiftData

/// The service's categorical judgement of one answer — never a number
/// (ARCHITECTURE.md §1).
enum AnswerQuality: String, Codable, CaseIterable, Sendable {
    case strong
    case adequate
    case weak
}

/// A theme or signal: its text plus the grounding quote that makes it a
/// claim, not speculation (decisions/0002).
struct GroundedRemark: Codable, Hashable, Sendable {
    var text: String
    var quote: String
}

/// The evidence-based analysis of one Stage's call. One per Stage;
/// regenerating replaces ([DEBRIEF-15]).
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

/// One question the interviewer asked, as the service reported it. A model
/// row, not a value struct, so missed ammo can be a real relationship to
/// the canon (decisions/0001).
@Model
final class DebriefQuestion {
    var question: String
    var answerSummary: String
    var quality: AnswerQuality
    /// The verbatim excerpt of the notes overview this entry is grounded in
    /// (decisions/0002).
    var quote: String
    var sortIndex: Int
    var debrief: Debrief?

    /// Links to the Profile's canon — never copies, never a cascade toward
    /// the Profile (decisions/0001).
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

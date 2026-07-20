import Foundation
import SwiftData

/// One practice exercise for a technical-type Stage, tuned to the JD's
/// stack. Answered outside the app — the §6 v1 ruling: exported, not
/// interactive.
struct MockTask: Codable, Hashable, Sendable {
    var title: String
    var brief: String
}

/// The preparation material for one upcoming Stage. One per Stage;
/// regenerating replaces ([PREP-17]). Forward-looking coaching, never
/// evidence (decisions/0002).
@Model
final class PrepPack {
    var generatedAt: Date
    var likelyQuestions: [String]
    var companyBrief: String?
    var mockTasks: [MockTask]
    var stage: Stage?

    @Relationship(deleteRule: .cascade, inverse: \PrepTalkingPoint.prepPack)
    var talkingPoints: [PrepTalkingPoint]

    /// To-many relationships are unordered; `sortIndex` carries the
    /// service's order.
    var orderedTalkingPoints: [PrepTalkingPoint] {
        talkingPoints.sorted { $0.sortIndex < $1.sortIndex }
    }

    init(
        generatedAt: Date,
        likelyQuestions: [String] = [],
        companyBrief: String? = nil,
        mockTasks: [MockTask] = []
    ) {
        self.generatedAt = generatedAt
        self.likelyQuestions = likelyQuestions
        self.companyBrief = companyBrief
        self.mockTasks = mockTasks
        self.talkingPoints = []
    }
}

/// One thing worth saying at the Stage, as the service proposed it. A model
/// row, not a value struct, so mapped achievements can be a real
/// relationship to the canon (decisions/0001).
@Model
final class PrepTalkingPoint {
    var text: String
    var sortIndex: Int
    var prepPack: PrepPack?

    /// Links to the Profile's canon — never copies, never a cascade toward
    /// the Profile (decisions/0001).
    var achievements: [Achievement]

    init(text: String, sortIndex: Int = 0, achievements: [Achievement] = []) {
        self.text = text
        self.sortIndex = sortIndex
        self.achievements = achievements
    }
}

extension StageKind {
    /// The kinds whose prep pack carries mock tasks (CONTEXT.md:
    /// technical-type Stage).
    var isTechnicalType: Bool {
        switch self {
        case .technical, .systemDesign, .takeHome: true
        default: false
        }
    }
}

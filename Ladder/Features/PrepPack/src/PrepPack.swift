import Foundation
import SwiftData

struct MockTask: Codable, Hashable, Sendable {
    var title: String
    var brief: String
}

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
    var isTechnicalType: Bool {
        switch self {
        case .technical, .systemDesign, .takeHome: true
        default: false
        }
    }
}

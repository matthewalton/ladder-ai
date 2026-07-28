import Foundation
import SwiftData

enum StageKind: Hashable, Sendable {
    case screen
    case recruiter
    case technical
    case systemDesign
    case takeHome
    case behavioral
    case final
    case offer
    case other(String)

    static let knownCases: [StageKind] = [
        .screen, .recruiter, .technical, .systemDesign,
        .takeHome, .behavioral, .final, .offer,
    ]

    var rawValue: String {
        switch self {
        case .screen: "screen"
        case .recruiter: "recruiter"
        case .technical: "technical"
        case .systemDesign: "systemDesign"
        case .takeHome: "takeHome"
        case .behavioral: "behavioral"
        case .final: "final"
        case .offer: "offer"
        case .other(let label): label
        }
    }

    init(rawValue: String) {
        if let known = Self.knownCases.first(where: { $0.rawValue == rawValue }) {
            self = known
        } else {
            self = .other(rawValue)
        }
    }
}

enum StageOutcome: String, Codable, CaseIterable, Sendable {
    case pending
    case passed
    case failed
    case noResponse
}

@Model
final class Stage {
    var kindRaw: String
    var scheduledAt: Date?
    var calendarEventID: String?
    var meetingURL: URL?
    var prepContext: String
    var outcome: StageOutcome
    var heardBackAt: Date?
    /// Carries the chain's order — SwiftData to-many relationships are unordered.
    var sortIndex: Int
    var application: Application?

    /// Owned by the transcript-import slice — see Ladder/Features/TranscriptImport/.
    @Relationship(deleteRule: .cascade, inverse: \Transcript.stage)
    var transcript: Transcript?

    /// Owned by the debrief slice — see Ladder/Features/Debrief/.
    @Relationship(deleteRule: .cascade, inverse: \Debrief.stage)
    var debrief: Debrief?

    /// Owned by the prep-pack slice — see Ladder/Features/PrepPack/.
    @Relationship(deleteRule: .cascade, inverse: \PrepPack.stage)
    var prepPack: PrepPack?

    var kind: StageKind {
        get { StageKind(rawValue: kindRaw) }
        set { kindRaw = newValue.rawValue }
    }

    init(
        kind: StageKind,
        scheduledAt: Date? = nil,
        calendarEventID: String? = nil,
        meetingURL: URL? = nil,
        prepContext: String = "",
        outcome: StageOutcome = .pending,
        heardBackAt: Date? = nil,
        sortIndex: Int = 0
    ) {
        self.kindRaw = kind.rawValue
        self.scheduledAt = scheduledAt
        self.calendarEventID = calendarEventID
        self.meetingURL = meetingURL
        self.prepContext = prepContext
        self.outcome = outcome
        self.heardBackAt = heardBackAt
        self.sortIndex = sortIndex
    }
}

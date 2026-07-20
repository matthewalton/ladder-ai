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

    /// Picker source — deliberately omits `.other`; the form's free-text row
    /// is the only way to produce one.
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

/// One step in an Application's interview loop.
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

    /// One conversation per Stage; deleting the Stage deletes it too
    /// (owned by the transcript-import slice — see Ladder/TranscriptImport/).
    @Relationship(deleteRule: .cascade, inverse: \Transcript.stage)
    var transcript: Transcript?

    /// One debrief per Stage; deleting the Stage deletes it too
    /// (owned by the debrief slice — see Ladder/Debrief/).
    @Relationship(deleteRule: .cascade, inverse: \Debrief.stage)
    var debrief: Debrief?

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

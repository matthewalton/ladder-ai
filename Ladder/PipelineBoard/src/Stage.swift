import Foundation
import SwiftData

/// What sort of step a Stage is (slice CONTEXT.md: stage kind). Persisted as
/// a raw string, never as an associated-value enum (decisions/0002): known
/// cases map to fixed strings, anything else round-trips as `.other`.
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

    /// Picker source — never offers `.other`; the form's free-text row is
    /// the only way to produce one (decisions/0002).
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

/// How a Stage resolved (slice CONTEXT.md: stage outcome) — the
/// `ApplicationStatus` pattern: plain string raw values.
enum StageOutcome: String, Codable, CaseIterable, Sendable {
    case pending
    case passed
    case failed
    case noResponse
}

/// One step in an Application's interview loop (root CONTEXT.md). Phase 2
/// shape: the gated `prepPack`/`transcript`/`debrief` fields wait for their
/// phases; `calendarEventID`/`meetingURL` are stored now for calendar-sync
/// to consume (SPEC.md intro). `sortIndex` carries the chain's order — to-many
/// relationships are unordered ([PIPEBOARD-10], the [PROFILE-7] pattern).
@Model
final class Stage {
    var kindRaw: String
    var scheduledAt: Date?
    var calendarEventID: String?
    var meetingURL: URL?
    var prepContext: String
    var outcome: StageOutcome
    var heardBackAt: Date?
    var sortIndex: Int
    var application: Application?

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

import Foundation

/// The calendar permission, as the slice sees it. Denied is a state, not an
/// error (decisions/0001, [CALSYNC-17]).
enum CalendarAccessState: Equatable, Sendable {
    case notDetermined
    case granted
    case denied
}

/// All calendar access goes through this seam (decisions/0001), mirroring
/// `IntelligenceService`: the fixture implementation serves tests and
/// previews, the EventKit one is human-only. The posture is read-only — the
/// protocol has no write operation.
protocol CalendarSyncService: Sendable {
    func accessState() async -> CalendarAccessState
    /// Prompts the user when not determined; never called on launch — only
    /// from an explicit user action (decisions/0001).
    func requestAccess() async -> CalendarAccessState
    /// Events overlapping the interval, already filtered to it. The store
    /// computes the window and passes it in ([CALSYNC-13]).
    func events(in interval: DateInterval) async throws -> [CalendarEvent]
}

extension Notification.Name {
    /// The service-agnostic change signal (decisions/0003): the live service
    /// reposts `EKEventStoreChanged` as this; tests post it directly
    /// ([CALSYNC-14]).
    static let calendarSyncDidChange = Notification.Name("LadderCalendarSyncDidChange")
}

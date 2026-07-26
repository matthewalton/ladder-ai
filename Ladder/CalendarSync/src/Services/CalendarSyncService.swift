import Foundation

enum CalendarAccessState: Equatable, Sendable {
    case notDetermined
    case granted
    case denied
}

/// All calendar access crosses this seam; the posture is read-only — the
/// protocol has no write operation.
protocol CalendarSyncService: Sendable {
    func accessState() async -> CalendarAccessState
    /// Prompts the user; never called on launch — only from an explicit
    /// user action.
    func requestAccess() async -> CalendarAccessState
    /// Events overlapping the interval, already filtered to it.
    func events(in interval: DateInterval) async throws -> [CalendarEvent]
}

extension Notification.Name {
    /// The live service reposts `EKEventStoreChanged` as this; tests post
    /// it directly.
    static let calendarSyncDidChange = Notification.Name("LadderCalendarSyncDidChange")
}

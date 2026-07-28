import Foundation

enum CalendarAccessState: Equatable, Sendable {
    case notDetermined
    case granted
    case denied
}

/// All calendar access crosses this seam; the posture is read-only.
protocol CalendarSyncService: Sendable {
    func accessState() async -> CalendarAccessState
    /// Prompts the user; never called on launch — only from an explicit
    /// user action.
    func requestAccess() async -> CalendarAccessState
    func events(in interval: DateInterval) async throws -> [CalendarEvent]
}

extension Notification.Name {
    /// The live service reposts `EKEventStoreChanged` as this; tests post
    /// it directly.
    static let calendarSyncDidChange = Notification.Name("LadderCalendarSyncDidChange")
}

import Foundation
import SwiftData

/// Dismissal is per event identifier, forever — a changed event stays
/// dismissed.
@Model
final class DismissedEvent {
    var calendarEventID: String
    var dismissedAt: Date

    init(calendarEventID: String, dismissedAt: Date = .now) {
        self.calendarEventID = calendarEventID
        self.dismissedAt = dismissedAt
    }
}

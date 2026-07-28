import Foundation
import SwiftData

@Model
final class DismissedEvent {
    var calendarEventID: String
    var dismissedAt: Date

    init(calendarEventID: String, dismissedAt: Date = .now) {
        self.calendarEventID = calendarEventID
        self.dismissedAt = dismissedAt
    }
}

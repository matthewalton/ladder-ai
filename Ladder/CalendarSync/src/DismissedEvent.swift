import Foundation
import SwiftData

/// A proposal the user declined, kept so the event never comes back
/// (decisions/0004): dismissal is per event identifier, forever — a changed
/// event stays dismissed, the identifier is the identity.
@Model
final class DismissedEvent {
    var calendarEventID: String
    var dismissedAt: Date

    init(calendarEventID: String, dismissedAt: Date = .now) {
        self.calendarEventID = calendarEventID
        self.dismissedAt = dismissedAt
    }
}

import Foundation

/// A calendar event as it crosses the `CalendarSyncService` seam — a plain
/// value, never an `EKEvent` (decisions/0001), so fixtures and tests build
/// them in code with no calendar permission.
struct CalendarEvent: Equatable, Sendable, Identifiable {
    var identifier: String
    var title: String
    var start: Date
    var end: Date?
    var location: String?
    var notes: String?
    var attendeeEmails: [String]
    var organizerName: String?
    var organizerEmail: String?

    var id: String { identifier }

    init(
        identifier: String,
        title: String,
        start: Date,
        end: Date? = nil,
        location: String? = nil,
        notes: String? = nil,
        attendeeEmails: [String] = [],
        organizerName: String? = nil,
        organizerEmail: String? = nil
    ) {
        self.identifier = identifier
        self.title = title
        self.start = start
        self.end = end
        self.location = location
        self.notes = notes
        self.attendeeEmails = attendeeEmails
        self.organizerName = organizerName
        self.organizerEmail = organizerEmail
    }
}

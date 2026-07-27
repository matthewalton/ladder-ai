import Foundation

/// The known-interview escape (decisions/0008): the human reviewing a check
/// knows the interview they're looking for, so typing beats scrolling.
enum OtherEventsFilter {
    /// Case-insensitive title containment; a blank filter keeps everything.
    static func filtered(
        _ events: [CalendarEvent], titleContains query: String
    ) -> [CalendarEvent] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return events }
        return events.filter {
            $0.title.range(of: trimmed, options: .caseInsensitive) != nil
        }
    }
}

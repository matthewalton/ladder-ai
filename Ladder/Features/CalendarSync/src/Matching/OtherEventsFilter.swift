import Foundation

enum OtherEventsFilter {
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

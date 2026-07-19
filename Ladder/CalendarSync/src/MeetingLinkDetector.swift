import Foundation

/// A closed set: anything not Zoom, Meet, or Teams is not a meeting link.
enum MeetingLinkDetector {
    private static let recognisedHosts = [
        "zoom.us", "meet.google.com", "teams.microsoft.com", "teams.live.com",
    ]

    static func meetingLink(in event: CalendarEvent) -> URL? {
        for text in [event.location, event.notes].compactMap({ $0 }) {
            if let url = firstRecognisedLink(in: text) {
                return url
            }
        }
        return nil
    }

    private static func firstRecognisedLink(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        for match in detector.matches(in: text, range: range) {
            guard let url = match.url, let host = url.host()?.lowercased() else { continue }
            if recognisedHosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) {
                return url
            }
        }
        return nil
    }
}

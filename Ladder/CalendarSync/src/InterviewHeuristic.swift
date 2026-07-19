import Foundation

/// The interview heuristic (decisions/0007): flags an event matching no
/// tracked Application as a possible interview. Two signals — an interview
/// keyword in the title ([CALSYNC-21]) or a recognised meeting link
/// ([CALSYNC-22]); neither → no proposal ([CALSYNC-23]). Flags only: it
/// never matches and never creates.
enum InterviewHeuristic {
    /// One vocabulary, two uses (decisions/0007): the word "interview" plus
    /// the kind guess's keyword table (decisions/0005) — no second list to
    /// drift.
    static let vocabulary: [String] = ["interview"] + StageKindGuesser.allKeywords

    static func flags(_ event: CalendarEvent) -> Bool {
        hasKeyword(in: event.title) || MeetingLinkDetector.meetingLink(in: event) != nil
    }

    /// Whole-word phrase containment — unlike the kind guess's substring
    /// match, so "Sunscreen shopping" never flags on "screen".
    static func hasKeyword(in title: String) -> Bool {
        let words = tokenise(title)
        return vocabulary.contains { containsPhrase(tokenise($0), in: words) }
    }

    /// Lowercased alphanumeric words — hyphens split, so "take-home" and
    /// "take home" tokenise alike.
    static func tokenise(_ text: String) -> [String] {
        String(text.lowercased().map { $0.isLetter || $0.isNumber ? $0 : " " })
            .split(separator: " ")
            .map(String.init)
    }

    private static func containsPhrase(_ needle: [String], in haystack: [String]) -> Bool {
        guard !needle.isEmpty, haystack.count >= needle.count else { return false }
        return (0...(haystack.count - needle.count)).contains { start in
            Array(haystack[start ..< start + needle.count]) == needle
        }
    }
}

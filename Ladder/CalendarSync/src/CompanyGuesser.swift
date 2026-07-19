import Foundation

/// The company guess (decisions/0007): the pre-fill for the confirmation
/// sheet's company field on a possible-interview proposal. Domain first
/// ([CALSYNC-24]), title fallback ([CALSYNC-25]); like the kind guess, it
/// only ever pre-fills — the field stays editable.
enum CompanyGuesser {
    /// Words that connect without naming — stripped alongside the interview
    /// vocabulary in the title fallback.
    private static let connectives: Set<String> = [
        "with", "at", "the", "a", "an", "and", "or", "for", "of", "on",
        "to", "in", "round", "call", "chat", "meeting", "w", "x", "vs",
    ]

    static func guess(for event: CalendarEvent) -> String {
        let emails = event.attendeeEmails + [event.organizerEmail].compactMap { $0 }
        if let label = emails.lazy.compactMap(CalendarMatcher.companyLabel(ofEmail:)).first {
            return cased(label, fromTitle: event.title)
        }
        return strippedTitle(event.title)
    }

    /// The registrable-domain label, cased from the title when it appears
    /// there as a word — `waynetech` + "Interview with WayneTech" →
    /// "WayneTech" ([CALSYNC-24]).
    private static func cased(_ label: String, fromTitle title: String) -> String {
        casedWords(title).first { $0.lowercased() == label } ?? label
    }

    /// The title fallback ([CALSYNC-25]): drop every interview-vocabulary
    /// phrase and connective word; what remains — original order, original
    /// casing — is the guess. Nothing left → empty.
    private static func strippedTitle(_ title: String) -> String {
        let words = casedWords(title)
        let lowered = words.map { $0.lowercased() }
        var dropped = [Bool](repeating: false, count: words.count)
        for phrase in InterviewHeuristic.vocabulary {
            let needle = InterviewHeuristic.tokenise(phrase)
            guard !needle.isEmpty, lowered.count >= needle.count else { continue }
            for start in 0...(lowered.count - needle.count)
            where Array(lowered[start ..< start + needle.count]) == needle {
                for index in start ..< start + needle.count {
                    dropped[index] = true
                }
            }
        }
        return words.indices
            .filter { !dropped[$0] && !connectives.contains(lowered[$0]) }
            .map { words[$0] }
            .joined(separator: " ")
    }

    /// Alphanumeric words with their original casing kept.
    private static func casedWords(_ text: String) -> [String] {
        text.split { !($0.isLetter || $0.isNumber) }.map(String.init)
    }
}

import Foundation

/// The matching policy (decisions/0002): two signals, both exact after
/// normalisation, no edit-distance. Pure helpers — testable without EventKit.
enum CalendarMatcher {
    /// Corporate suffixes dropped during normalisation (decisions/0002).
    private static let corporateSuffixes: Set<String> = [
        "corp", "corporation", "inc", "ltd", "llc", "gmbh", "plc", "co",
    ]

    /// Public mail providers that are never company evidence
    /// (decisions/0002, [CALSYNC-4]).
    private static let publicMailDomains: Set<String> = [
        "gmail.com", "googlemail.com", "outlook.com", "hotmail.com",
        "live.com", "yahoo.com", "icloud.com", "me.com", "proton.me",
        "protonmail.com",
    ]

    /// Registrable-domain second-level labels that are not company names —
    /// `acme.co.uk` normalises to `acme`, not `co`.
    private static let secondLevelLabels: Set<String> = [
        "co", "com", "org", "net", "ac", "gov", "edu",
    ]

    /// Lowercase, strip punctuation, collapse whitespace ([CALSYNC-5]), drop
    /// corporate suffixes — as word arrays so containment is whole-word:
    /// "Acme" never matches "Acmex".
    static func normalisedWords(_ text: String) -> [String] {
        let cleaned = String(
            text.lowercased().map { character in
                (character.isLetter || character.isNumber) ? character : " "
            }
        )
        return cleaned.split(separator: " ")
            .map(String.init)
            .filter { !corporateSuffixes.contains($0) }
    }

    /// Whole-word-sequence containment of the normalised company name in the
    /// normalised text.
    static func contains(_ text: String, company: String) -> Bool {
        let haystack = normalisedWords(text)
        let needle = normalisedWords(company)
        guard !needle.isEmpty, haystack.count >= needle.count else { return false }
        return (0...(haystack.count - needle.count)).contains { start in
            Array(haystack[start ..< start + needle.count]) == needle
        }
    }

    /// The registrable-domain label of an email address — `jane@mail.acme.com`
    /// → `acme` — or nil for a malformed address or a public mail provider.
    static func companyLabel(ofEmail email: String) -> String? {
        let parts = email.lowercased().split(separator: "@")
        guard parts.count == 2 else { return nil }
        let domain = String(parts[1])
        guard !publicMailDomains.contains(where: { domain == $0 || domain.hasSuffix("." + $0) })
        else { return nil }
        let labels = domain.split(separator: ".").map(String.init)
        guard labels.count >= 2 else { return nil }
        var index = labels.count - 2
        if labels.count >= 3 && secondLevelLabels.contains(labels[index]) {
            index -= 1
        }
        return labels[index]
    }

    /// The attendee-domain signal (decisions/0002, [CALSYNC-4]): the label
    /// equals the normalised company name's first word or its joined form
    /// (`acme corp` → `acme` or `acmecorp`).
    static func domainMatches(email: String, company: String) -> Bool {
        guard let label = companyLabel(ofEmail: email) else { return false }
        let words = normalisedWords(company)
        guard let first = words.first else { return false }
        return label == first || label == words.joined()
    }

    /// Whether the event matches the company by either signal
    /// (decisions/0002): company name in the title or organizer name, or an
    /// attendee/organizer email domain.
    static func matches(event: CalendarEvent, company: String) -> Bool {
        if contains(event.title, company: company) { return true }
        if let organizerName = event.organizerName, contains(organizerName, company: company) {
            return true
        }
        let emails = event.attendeeEmails + [event.organizerEmail].compactMap { $0 }
        return emails.contains { domainMatches(email: $0, company: company) }
    }
}

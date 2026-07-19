import Foundation

/// Matching is exact after normalisation — no edit-distance, by design.
enum CalendarMatcher {
    private static let corporateSuffixes: Set<String> = [
        "corp", "corporation", "inc", "ltd", "llc", "gmbh", "plc", "co",
    ]

    private static let publicMailDomains: Set<String> = [
        "gmail.com", "googlemail.com", "outlook.com", "hotmail.com",
        "live.com", "yahoo.com", "icloud.com", "me.com", "proton.me",
        "protonmail.com",
    ]

    /// Senders the calendar plumbing puts on an event, not the company —
    /// `unknownorganizer@calendar.google.com` is not evidence of Google.
    private static let infrastructureDomains: Set<String> = [
        "calendar.google.com", "calendly.com",
    ]

    /// `acme.co.uk` yields `acme`, not `co`.
    private static let secondLevelLabels: Set<String> = [
        "co", "com", "org", "net", "ac", "gov", "edu",
    ]

    /// Word arrays keep containment whole-word: "Acme" never matches "Acmex".
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

    static func contains(_ text: String, company: String) -> Bool {
        let haystack = normalisedWords(text)
        let needle = normalisedWords(company)
        guard !needle.isEmpty, haystack.count >= needle.count else { return false }
        return (0...(haystack.count - needle.count)).contains { start in
            Array(haystack[start ..< start + needle.count]) == needle
        }
    }

    /// `jane@mail.acme.com` → `acme`; nil for a malformed address or a
    /// denied domain.
    static func companyLabel(ofEmail email: String) -> String? {
        let parts = email.lowercased().split(separator: "@")
        guard parts.count == 2 else { return nil }
        let domain = String(parts[1])
        let denied = publicMailDomains.union(infrastructureDomains)
        guard !denied.contains(where: { domain == $0 || domain.hasSuffix("." + $0) })
        else { return nil }
        let labels = domain.split(separator: ".").map(String.init)
        guard labels.count >= 2 else { return nil }
        var index = labels.count - 2
        if labels.count >= 3 && secondLevelLabels.contains(labels[index]) {
            index -= 1
        }
        return labels[index]
    }

    static func domainMatches(email: String, company: String) -> Bool {
        guard let label = companyLabel(ofEmail: email) else { return false }
        let words = normalisedWords(company)
        guard let first = words.first else { return false }
        return label == first || label == words.joined()
    }

    static func matches(event: CalendarEvent, company: String) -> Bool {
        if contains(event.title, company: company) { return true }
        if let organizerName = event.organizerName, contains(organizerName, company: company) {
            return true
        }
        let emails = event.attendeeEmails + [event.organizerEmail].compactMap { $0 }
        return emails.contains { domainMatches(email: $0, company: company) }
    }
}

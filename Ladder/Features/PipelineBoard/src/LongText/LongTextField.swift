import Foundation

struct LongTextIndicator: Equatable {
    var label: String
    var snippet: String
}

enum LongTextField {
    static let snippetLimit = 80

    static func collapsesAtAppearance(_ text: String) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func indicator(
        name: String, text: String, locale: Locale = .autoupdatingCurrent
    ) -> LongTextIndicator {
        let words = text.split(whereSeparator: \.isWhitespace)
        let count = words.count.formatted(.number.locale(locale))
        return LongTextIndicator(
            label: "\(name) — \(count) \(words.count == 1 ? "word" : "words")",
            snippet: snippet(fromWords: words))
    }

    private static func snippet(fromWords words: [Substring]) -> String {
        let normalised = words.joined(separator: " ")
        guard normalised.count > snippetLimit else { return normalised }

        let head = normalised.prefix(snippetLimit)
        let endsMidWord = normalised[normalised.index(
            normalised.startIndex, offsetBy: snippetLimit)] != " "
        let kept = endsMidWord ? head[..<(head.lastIndex(of: " ") ?? head.endIndex)] : head
        return kept + "…"
    }
}

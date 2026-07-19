import Foundation

/// Live models sometimes wrap their JSON in a markdown code fence despite
/// prompts forbidding it; the fence is presentation, not content.
enum FencedJSON {
    static func stripped(from data: Data) -> Data {
        guard let raw = String(data: data, encoding: .utf8) else { return data }
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.hasPrefix("```"), text.hasSuffix("```"), text.count > 6 else { return data }
        text.removeLast(3)
        // The opening fence line goes whole — it may carry a language tag.
        guard let firstNewline = text.firstIndex(of: "\n") else { return data }
        text = String(text[text.index(after: firstNewline)...])
        return Data(text.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
    }
}

import Foundation

enum GranolaShareError: Error, Equatable {
    case fetchFailed
    /// The page's payload carries no shared document — not a share link,
    /// or Granola changed the page internals (decisions/0006).
    case noSharedDocument
}

/// The fetch seam (decisions/0006): tests use a fixture, the app the live
/// URLSession fetcher — the `IntelligenceService` pattern.
protocol GranolaShareFetching: Sendable {
    func html(from url: URL) async throws -> String
}

struct LiveGranolaShareFetcher: GranolaShareFetching {
    func html(from url: URL) async throws -> String {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
            let html = String(data: data, encoding: .utf8)
        else { throw GranolaShareError.fetchFailed }
        return html
    }
}

/// What a share link's page embeds (CONTEXT.md "shared document").
struct SharedDocument: Equatable {
    var title: String?
    var createdAt: Date?
    var notesText: String
    /// nil when the link carried no usable transcript ([TRANSCRIPT-24]) —
    /// an unrecognized shape also lands here, never a guess.
    var segments: [Segment]?
}

extension ISO8601DateFormatter {
    /// Granola's `created_at` carries fractional seconds. A fresh instance
    /// per access: the formatter is not Sendable.
    static var granolaPayload: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
}

/// Pure parsing of a Granola share page. The payload is a page internal
/// (Next.js RSC flight chunks), not an API contract — everything here fails
/// toward `noSharedDocument` or notes-only rather than guessing.
enum GranolaSharePayload {
    /// The URL door opens only for a lone `notes.granola.ai/t/…` URL
    /// ([TRANSCRIPT-27]); anything else is a paste.
    static func shareLink(in text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isWhitespace),
            let url = URL(string: trimmed),
            url.scheme == "https" || url.scheme == "http",
            url.host() == "notes.granola.ai",
            url.path().hasPrefix("/t/")
        else { return nil }
        return url
    }

    static func parse(html: String) throws -> SharedDocument {
        let payload = flightPayload(in: html)
        guard let panel = jsonValue(after: "\"documentPanel\":", in: payload) as? [String: Any]
        else { throw GranolaShareError.noSharedDocument }

        let document = panel["document"] as? [String: Any]
        let createdAt = (document?["created_at"] as? String)
            .flatMap(ISO8601DateFormatter.granolaPayload.date(from:))

        var lines: [String] = []
        if let content = (panel["panel"] as? [String: Any])?["content"] as? [String: Any] {
            flattenNotes(content, bulletDepth: 0, into: &lines)
        }
        // Granola appends a "Chat with meeting transcript: <url>" line for
        // its own logged-in web app; on an anonymous import it is dead
        // weight ([TRANSCRIPT-22]).
        lines.removeAll { $0.hasPrefix("Chat with meeting transcript:") }

        return SharedDocument(
            title: document?["title"] as? String,
            createdAt: createdAt,
            notesText: lines.joined(separator: "\n"),
            segments: transcriptSegments(in: payload)
        )
    }

    // MARK: - RSC flight payload

    /// Concatenates every `self.__next_f.push([1,"…"])` chunk, JS-unescaped.
    private static func flightPayload(in html: String) -> String {
        let pattern = #"self\.__next_f\.push\(\[1,"((?:[^"\\]|\\.)*)"\]\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return "" }
        let range = NSRange(html.startIndex..., in: html)
        return regex.matches(in: html, range: range).compactMap { match -> String? in
            guard let chunkRange = Range(match.range(at: 1), in: html) else { return nil }
            // The captured text is a JSON string literal's body — decode it
            // by wrapping it back in quotes.
            return try? JSONDecoder().decode(String.self, from: Data("\"\(html[chunkRange])\"".utf8))
        }.joined()
    }

    /// Extracts and parses the JSON value following `marker` — an object,
    /// array, string, or null — by string-aware balanced scanning.
    private static func jsonValue(after marker: String, in payload: String) -> Any? {
        guard let markerRange = payload.range(of: marker) else { return nil }
        var index = markerRange.upperBound
        while index < payload.endIndex, payload[index].isWhitespace {
            index = payload.index(after: index)
        }
        guard index < payload.endIndex else { return nil }

        let start = index
        switch payload[index] {
        case "{", "[":
            let open = payload[index]
            let close: Character = open == "{" ? "}" : "]"
            var depth = 0
            var inString = false
            var escaped = false
            while index < payload.endIndex {
                let ch = payload[index]
                if inString {
                    if escaped { escaped = false } else if ch == "\\" { escaped = true } else if ch == "\"" { inString = false }
                } else {
                    if ch == "\"" { inString = true } else if ch == open { depth += 1 } else if ch == close {
                        depth -= 1
                        if depth == 0 { break }
                    }
                }
                index = payload.index(after: index)
            }
            guard index < payload.endIndex else { return nil }
            let json = String(payload[start...index])
            return try? JSONSerialization.jsonObject(with: Data(json.utf8), options: [.fragmentsAllowed])
        case "\"":
            index = payload.index(after: index)
            var escaped = false
            while index < payload.endIndex {
                let ch = payload[index]
                if escaped { escaped = false } else if ch == "\\" { escaped = true } else if ch == "\"" { break }
                index = payload.index(after: index)
            }
            guard index < payload.endIndex else { return nil }
            let literal = String(payload[start...index])
            return try? JSONDecoder().decode(String.self, from: Data(literal.utf8))
        default:
            return payload[index...].hasPrefix("null") ? NSNull() : nil
        }
    }

    // MARK: - Notes tree

    /// Headings as `## ` lines, bullet items as `- ` lines indented by
    /// nesting ([TRANSCRIPT-22]).
    private static func flattenNotes(_ node: [String: Any], bulletDepth: Int, into lines: inout [String]) {
        let children = node["content"] as? [[String: Any]] ?? []
        switch node["type"] as? String {
        case "heading":
            lines.append("## " + inlineText(of: node))
        case "paragraph":
            let text = inlineText(of: node)
            if !text.isEmpty, bulletDepth == 0 { lines.append(text) }
        case "bulletList", "orderedList":
            for item in children {
                let indent = String(repeating: "  ", count: bulletDepth)
                let itemChildren = item["content"] as? [[String: Any]] ?? []
                for child in itemChildren {
                    switch child["type"] as? String {
                    case "paragraph":
                        lines.append(indent + "- " + inlineText(of: child))
                    default:
                        flattenNotes(child, bulletDepth: bulletDepth + 1, into: &lines)
                    }
                }
            }
        default:
            for child in children {
                flattenNotes(child, bulletDepth: bulletDepth, into: &lines)
            }
        }
    }

    private static func inlineText(of node: [String: Any]) -> String {
        let children = node["content"] as? [[String: Any]] ?? []
        return children.compactMap { child -> String? in
            if child["type"] as? String == "text" { return child["text"] as? String }
            return inlineText(of: child)
        }.joined()
    }

    // MARK: - Shared transcript

    /// Stream identity ([TRANSCRIPT-23]): `microphone` → me, any other
    /// source → them. The shape is unverified until a transcript-shared
    /// link is seen — anything unrecognized returns nil, never a guess.
    private static func transcriptSegments(in payload: String) -> [Segment]? {
        switch jsonValue(after: "\"documentTranscript\":", in: payload) {
        case let items as [[String: Any]]:
            let segments = items.compactMap { item -> Segment? in
                guard let text = item["text"] as? String, !text.isEmpty else { return nil }
                let source = (item["source"] as? String)?.lowercased()
                return Segment(
                    speaker: source == "microphone" ? .me : .them,
                    text: text,
                    tStart: numericSeconds(item["start_timestamp"]),
                    tEnd: numericSeconds(item["end_timestamp"])
                )
            }
            return segments.isEmpty ? nil : segments
        case let text as String:
            return try? TranscriptParser.parse(text)
        default:
            return nil
        }
    }

    private static func numericSeconds(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber: return number.doubleValue
        default: return nil
        }
    }
}

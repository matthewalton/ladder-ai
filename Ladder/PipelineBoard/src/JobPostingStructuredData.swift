import Foundation

/// The schema.org JobPosting block ATS pages embed for search engines
/// ([PIPEBOARD-28]): the posting without the page chrome — and on
/// Ashby-class JS shells, the only place the posting exists at all.
@MainActor
enum JobPostingStructuredData {
    /// Nil when the page embeds no readable JobPosting — the caller falls
    /// back to whole-page extraction.
    static func text(fromHTMLData data: Data) -> String? {
        guard
            let html = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1)
        else { return nil }
        for json in ldJSONBlocks(in: html) {
            guard
                let object = try? JSONSerialization.jsonObject(with: Data(json.utf8)),
                let posting = jobPosting(in: object),
                let description = posting["description"] as? String,
                let body = try? FileTextExtractor.extractText(
                    fromFetchedData: Data(description.utf8))
            else { continue }
            var parts: [String] = []
            let title = (posting["title"] as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty {
                let organization =
                    ((posting["hiringOrganization"] as? [String: Any])?["name"] as? String ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                parts.append(organization.isEmpty ? title : "\(title) — \(organization)")
            }
            parts.append(body)
            return parts.joined(separator: "\n\n")
        }
        return nil
    }

    private static func ldJSONBlocks(in html: String) -> [String] {
        guard
            let regex = try? NSRegularExpression(
                pattern: #"<script[^>]*application/ld\+json[^>]*>(.*?)</script>"#,
                options: [.caseInsensitive, .dotMatchesLineSeparators]
            )
        else { return [] }
        let range = NSRange(html.startIndex..., in: html)
        return regex.matches(in: html, range: range).compactMap {
            Range($0.range(at: 1), in: html).map { String(html[$0]) }
        }
    }

    /// A posting may sit at the top level, inside an array, or under
    /// `@graph`.
    private static func jobPosting(in object: Any) -> [String: Any]? {
        if let dictionary = object as? [String: Any] {
            if isJobPosting(dictionary) { return dictionary }
            if let graph = dictionary["@graph"] { return jobPosting(in: graph) }
            return nil
        }
        if let array = object as? [Any] {
            for element in array {
                if let found = jobPosting(in: element) { return found }
            }
        }
        return nil
    }

    private static func isJobPosting(_ dictionary: [String: Any]) -> Bool {
        if let type = dictionary["@type"] as? String { return type == "JobPosting" }
        if let types = dictionary["@type"] as? [String] { return types.contains("JobPosting") }
        return false
    }
}

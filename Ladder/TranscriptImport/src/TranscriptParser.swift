import Foundation

enum TranscriptParseError: Error, Equatable {
    /// No labeled line means nothing can be attributed ([TRANSCRIPT-9]).
    case noSpeakerLabels
}

/// Pure text-in, segments-out parsing of Granola-style labeled transcripts.
/// A labeled line opens a segment; unlabeled lines join the open segment
/// ([TRANSCRIPT-7]). Attribution is the label heuristic (decisions/0001).
enum TranscriptParser {
    /// "MM:SS" or "H:MM:SS" → seconds.
    private static let timePattern = #"(?:\d{1,2}:)?\d{1,2}:\d{2}"#

    /// A labeled line: optional "[time]" or "[time - time]" prefix, a short
    /// name-like label, optional "(time)" or "(time - time)" suffix, a colon,
    /// then the turn's opening text. The label charset is deliberately
    /// name-shaped — letters, spaces, apostrophes, hyphens, periods — so
    /// prose containing a colon ("We discussed: budget") reads as
    /// continuation, not as a speaker.
    private static let labeledLine = try! NSRegularExpression(
        pattern: #"""
            ^\s*
            (?:\[\s*(?<bStart>TIME)\s*(?:-\s*(?<bEnd>TIME)\s*)?\]\s*)?
            (?<label>[\p{L}][\p{L}\p{M}'’.\-\x20]{0,39}?)\s*
            (?:\(\s*(?<pStart>TIME)\s*(?:-\s*(?<pEnd>TIME)\s*)?\)\s*)?
            :\s*(?<text>.*)$
            """#.replacingOccurrences(of: "TIME", with: timePattern),
        options: [.allowCommentsAndWhitespace]
    )

    static func parse(_ text: String) throws -> [Segment] {
        var segments: [Segment] = []
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            if let turn = matchLabeledLine(line) {
                var segment = Segment(
                    speaker: turn.label.lowercased() == "me" ? .me : .them,
                    text: turn.text,
                    tStart: turn.tStart,
                    tEnd: turn.tEnd
                )
                if segment.text.isEmpty { segment.text = "" }
                segments.append(segment)
            } else if !segments.isEmpty {
                let joined = segments[segments.count - 1].text
                segments[segments.count - 1].text = joined.isEmpty ? line : joined + " " + line
            }
            // A leading unlabeled line (before any speaker) is dropped — it
            // cannot be attributed, and refusing the whole paste for a stray
            // header would be harsher than the spec asks.
        }
        guard !segments.isEmpty else { throw TranscriptParseError.noSpeakerLabels }
        return segments
    }

    /// `durationSec` derives from the last timestamp present, else 0
    /// (decisions/0002 — 0 means unknown).
    static func duration(of segments: [Segment]) -> Int {
        guard let last = segments.last(where: { $0.tEnd != nil || $0.tStart != nil }) else {
            return 0
        }
        return Int(last.tEnd ?? last.tStart ?? 0)
    }

    private struct LabeledTurn {
        var label: String
        var text: String
        var tStart: Double?
        var tEnd: Double?
    }

    private static func matchLabeledLine(_ line: String) -> LabeledTurn? {
        let range = NSRange(line.startIndex..., in: line)
        guard let match = labeledLine.firstMatch(in: line, range: range) else { return nil }
        func group(_ name: String) -> String? {
            let nsRange = match.range(withName: name)
            guard nsRange.location != NSNotFound, let r = Range(nsRange, in: line) else { return nil }
            return String(line[r])
        }
        guard let label = group("label") else { return nil }
        // "https://…" is a URL, not a speaker turn — without this, "https"
        // reads as a label and [TRANSCRIPT-27] could never refuse.
        if group("text")?.hasPrefix("//") == true { return nil }
        let start = group("bStart") ?? group("pStart")
        let end = group("bEnd") ?? group("pEnd")
        return LabeledTurn(
            label: label.trimmingCharacters(in: .whitespaces),
            text: group("text")?.trimmingCharacters(in: .whitespaces) ?? "",
            tStart: start.flatMap(seconds(from:)),
            tEnd: end.flatMap(seconds(from:))
        )
    }

    /// "01:23" → 83; "1:02:03" → 3723 — the third colon group is hours.
    private static func seconds(from time: String) -> Double? {
        let parts = time.split(separator: ":").map { Double($0) }
        guard parts.allSatisfy({ $0 != nil }) else { return nil }
        let values = parts.compactMap { $0 }
        switch values.count {
        case 2: return values[0] * 60 + values[1]
        case 3: return values[0] * 3600 + values[1] * 60 + values[2]
        default: return nil
        }
    }
}

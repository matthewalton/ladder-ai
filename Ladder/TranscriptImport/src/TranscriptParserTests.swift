import Foundation
import Testing

@testable import Ladder

struct TranscriptParserTests {
    @Test("[TRANSCRIPT-5] a line labeled Me parses into a segment attributed to me")
    func meLabelAttributesMe() throws {
        for label in ["Me", "me", "ME"] {
            let segments = try TranscriptParser.parse("\(label): I led the migration.")
            #expect(segments.map(\.speaker) == [.me], "label \"\(label)\" is me — the match is case-insensitive")
            #expect(segments.first?.text == "I led the migration.")
        }
    }

    @Test("[TRANSCRIPT-6] a line labeled with any other speaker parses into a segment attributed to them")
    func otherLabelsAttributeThem() throws {
        for label in ["Jane Doe", "Them", "Interviewer", "Dr. O'Brien-Smith"] {
            let segments = try TranscriptParser.parse("\(label): Tell me about a hard bug.")
            #expect(segments.map(\.speaker) == [.them], "label \"\(label)\" is them")
            #expect(segments.first?.text == "Tell me about a hard bug.")
        }
    }

    @Test("[TRANSCRIPT-7] unlabeled lines following a speaker label join that speaker's segment")
    func continuationLinesJoinTheOpenSegment() throws {
        let text = """
            Me: I broke the outage story into
            three parts.

            Jane: Nice structure.
            """
        let segments = try TranscriptParser.parse(text)
        #expect(segments.count == 2, "blank lines are dropped, never segments")
        #expect(segments.first?.text == "I broke the outage story into three parts.")
        #expect(segments.last?.speaker == .them)
        #expect(segments.last?.text == "Nice structure.")
    }

    @Test("[TRANSCRIPT-8] a timestamp on a speaker line becomes the segment's start time")
    func timestampsParse() throws {
        let parenthesized = try TranscriptParser.parse("Me (01:23): Hello.")
        #expect(parenthesized.first?.tStart == 83)
        #expect(parenthesized.first?.tEnd == nil)

        let bracketed = try TranscriptParser.parse("[01:23] Me: Hello.")
        #expect(bracketed.first?.tStart == 83)

        let range = try TranscriptParser.parse("Jane (01:23 - 01:41): A range sets the end time too.")
        #expect(range.first?.tStart == 83)
        #expect(range.first?.tEnd == 101)

        let hours = try TranscriptParser.parse("Me (1:02:03): The third colon group is hours.")
        #expect(hours.first?.tStart == 3723)

        let bare = try TranscriptParser.parse("Me: No timestamp leaves both nil.")
        #expect(bare.first?.tStart == nil)
        #expect(bare.first?.tEnd == nil)
    }

    @Test("[TRANSCRIPT-8] durationSec derives from the last timestamp present, else 0")
    func durationDerivation() throws {
        let timed = try TranscriptParser.parse("Me (00:10): a\nJane (01:23 - 01:41): b")
        #expect(TranscriptParser.duration(of: timed) == 101, "the last segment's end time wins")

        let startOnly = try TranscriptParser.parse("Me (00:10): a\nJane (01:23): b")
        #expect(TranscriptParser.duration(of: startOnly) == 83, "falls back to the last start time")

        let untimed = try TranscriptParser.parse("Me: a\nJane: b")
        #expect(TranscriptParser.duration(of: untimed) == 0, "0 means unknown, not instant")
    }

    @Test("[TRANSCRIPT-9] text with no speaker labels is refused")
    func unlabeledTextIsRefused() {
        #expect(throws: TranscriptParseError.noSpeakerLabels) {
            try TranscriptParser.parse("Just prose about the interview.\nNo labels anywhere.")
        }
        #expect(throws: TranscriptParseError.noSpeakerLabels) {
            try TranscriptParser.parse("   \n\n  ")
        }
    }
}

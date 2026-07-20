import Foundation
import Testing

@testable import Ladder

struct TranscriptReadoutTests {
    @Test("[TRANSCRIPT-17] the readout derives one row per segment in imported order")
    func oneRowPerSegmentInOrder() {
        let segments = [
            Segment(speaker: .me, text: "Thanks for making time.", tStart: 5),
            Segment(speaker: .them, text: "Of course."),
            Segment(speaker: .me, text: "Shall we start?"),
        ]
        let rows = TranscriptReadoutModel.rows(for: segments)
        #expect(rows.count == 3)
        #expect(rows.map(\.speaker) == [.me, .them, .me], "each row carries its segment's attribution")
        #expect(
            rows.map(\.text) == ["Thanks for making time.", "Of course.", "Shall we start?"],
            "rows follow the segments' stored order")
    }

    @Test("[TRANSCRIPT-18] a readout row carries its segment's timestamp label when the segment has a start time")
    func timestampLabelsRender() {
        let rows = TranscriptReadoutModel.rows(for: [
            Segment(speaker: .me, text: "a", tStart: 5),
            Segment(speaker: .them, text: "b", tStart: 83),
            Segment(speaker: .me, text: "c", tStart: 3723),
            Segment(speaker: .them, text: "d"),
        ])
        #expect(rows[0].timeLabel == "0:05")
        #expect(rows[1].timeLabel == "1:23", "M:SS below the hour")
        #expect(rows[2].timeLabel == "1:02:03", "H:MM:SS from the hour up")
        #expect(rows[3].timeLabel == nil, "an untimed segment among timed ones carries no label")
    }

    @Test("[TRANSCRIPT-19] a transcript whose segments carry no timestamps renders readout rows without time labels")
    func untimedTranscriptHasNoTimeLabels() {
        let rows = TranscriptReadoutModel.rows(for: [
            Segment(speaker: .me, text: "a"),
            Segment(speaker: .them, text: "b"),
        ])
        #expect(rows.allSatisfy { $0.timeLabel == nil }, "sequence order alone — never a 0:00 placeholder")
    }
}

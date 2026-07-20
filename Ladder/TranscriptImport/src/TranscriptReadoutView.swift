import SwiftUI

/// The transcript readout alone: one row per Segment in stored order
/// ([TRANSCRIPT-17]), timestamp labels when the segments carry times. The
/// notes overview renders separately (`NotesOverviewCard`) — the two
/// artifacts never share a section.
struct TranscriptReadoutView: View {
    var transcript: Transcript

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(TranscriptReadoutModel.rows(for: transcript.segments)) { row in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if let time = row.timeLabel {
                        Text(time)
                            .monospacedDigit()
                            .trailMetadata()
                    }
                    Text(row.speaker == .me ? "You" : "Them")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(row.speaker == .me ? Color.pine : Color.inkSoft)
                        .frame(width: 44, alignment: .leading)
                    Text(row.text)
                        .font(.callout)
                        .foregroundStyle(Color.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

/// The notes overview's card, shared by the Stage detail and the sheet
/// preview.
struct NotesOverviewCard: View {
    var notes: String

    var body: some View {
        Text(notes)
            .font(.trailNarrative(.callout))
            .foregroundStyle(Color.ink)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.pineTint, in: RoundedRectangle(cornerRadius: 6))
    }
}

#Preview {
    let transcript = Transcript(
        recordedAt: .now,
        durationSec: 101,
        notesSummary: "Strong on the outage story; follow up on system design.",
        segments: [
            Segment(speaker: .me, text: "Thanks for making time today.", tStart: 5),
            Segment(speaker: .them, text: "Of course — shall we dive in?", tStart: 9),
            Segment(speaker: .me, text: "Ready when you are."),
        ]
    )
    return VStack(alignment: .leading, spacing: 12) {
        NotesOverviewCard(notes: transcript.notesSummary ?? "")
        TranscriptReadoutView(transcript: transcript)
    }
    .padding()
    .frame(width: 420)
}

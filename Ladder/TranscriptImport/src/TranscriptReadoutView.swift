import SwiftUI

/// The Stage detail's readout: one row per Segment in stored order
/// ([TRANSCRIPT-17]), timestamp labels when the segments carry times.
struct TranscriptReadoutView: View {
    var transcript: Transcript

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let notes = transcript.notesSummary {
                Text(notes)
                    .font(.trailNarrative(.callout))
                    .foregroundStyle(Color.ink)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.pineTint, in: RoundedRectangle(cornerRadius: 6))
            }
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

#Preview {
    TranscriptReadoutView(
        transcript: Transcript(
            recordedAt: .now,
            durationSec: 101,
            notesSummary: "Strong on the outage story; follow up on system design.",
            segments: [
                Segment(speaker: .me, text: "Thanks for making time today.", tStart: 5),
                Segment(speaker: .them, text: "Of course — shall we dive in?", tStart: 9),
                Segment(speaker: .me, text: "Ready when you are."),
            ]
        )
    )
    .padding()
    .frame(width: 420)
}

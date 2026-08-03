import SwiftUI

/// The tailor flow sheet is as wide as the CV preview needs, and every other
/// phase declines that width. Capping is the default rather than something a
/// phase opts into, so a phase added later is held to the measure without
/// anyone remembering to list it.
struct ReadingMeasureView<Content: View>: View {
    var spendsFullWidth = false
    @ViewBuilder var content: Content

    var cappedWidth: CGFloat? {
        spendsFullWidth ? nil : TailorFlowSheetMetrics.readingMeasure
    }

    var body: some View {
        content
            .frame(maxWidth: cappedWidth ?? .infinity, maxHeight: .infinity)
            // The outer frame is what centres the capped content. Drop it and
            // the cap still holds, but every phase strands at the leading edge.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Reading measure") {
    ReadingMeasureView {
        VStack(alignment: .leading, spacing: 8) {
            Text("Why these were selected")
                .font(.headline)
                .foregroundStyle(Color.ink)
            Text(
                "The sheet is as wide as the CV preview needs, so every other phase is held to the reading measure and centred — the width becomes margin instead of a longer line."
            )
            .font(.callout)
            .foregroundStyle(Color.ink)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.paperRaised)
    }
    .frame(
        width: TailorFlowSheetMetrics.minWidth,
        height: TailorFlowSheetMetrics.minHeight)
    .background(Color.paper)
}

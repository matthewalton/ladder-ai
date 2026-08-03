import SwiftUI

enum ReadingMeasure {
    static let width: CGFloat = 720
}

struct ReadingMeasureView<Content: View>: View {
    var spendsFullWidth = false
    @ViewBuilder var content: Content

    var cappedWidth: CGFloat? {
        spendsFullWidth ? nil : ReadingMeasure.width
    }

    var body: some View {
        content
            .frame(maxWidth: cappedWidth ?? .infinity, maxHeight: .infinity)
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
    .frame(width: 1100, height: 640)
    .background(Color.paper)
}

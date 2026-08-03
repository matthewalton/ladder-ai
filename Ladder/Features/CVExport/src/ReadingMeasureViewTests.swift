import SwiftUI
import Testing

@testable import Ladder

struct ReadingMeasureViewTests {
    @Test("[CVEXPORT-65] a phase is held to the reading measure unless it says otherwise")
    func theCapIsTheDefault() {
        let phase = ReadingMeasureView { EmptyView() }

        #expect(
            phase.cappedWidth == TailorFlowSheetMetrics.readingMeasure,
            "a phase added later must be capped without anyone remembering to list it")
    }

    @Test("[CVEXPORT-65] the CV preview declines the cap and spends the sheet's full width")
    func thePreviewIsTheOneException() {
        let preview = ReadingMeasureView(spendsFullWidth: true) { EmptyView() }

        #expect(
            preview.cappedWidth == nil,
            "capping the preview would give back the page-pane width [CVEXPORT-64] bought")
    }

    @Test("[CVEXPORT-65] the cap leaves margin either side of the sheet's floor")
    func theCapLeavesMargin() {
        #expect(
            TailorFlowSheetMetrics.readingMeasure < TailorFlowSheetMetrics.minWidth,
            "a measure as wide as the sheet caps nothing, and the centring has nothing to centre")
    }
}

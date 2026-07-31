import CoreGraphics
import Testing

@testable import Ladder

struct TailorFlowSheetMetricsTests {
    @Test("[CVEXPORT-64] the page pane opens at least as wide as the A4 page it renders")
    func openingPagePaneClearsTheRenderedPage() {
        #expect(
            TailorFlowSheetMetrics.openingPagePaneWidth >= CVMetrics.pageSize.width,
            "a narrower pane scales the rendered CV down, and no gesture widens a sheet")
    }

    @Test("[CVEXPORT-64] both panes hold their minimums inside the sheet's floor")
    func bothPaneMinimumsFitTheFloor() {
        #expect(
            TailorFlowSheetMetrics.pagePaneMinWidth + TailorFlowSheetMetrics.editorMinWidth
                <= TailorFlowSheetMetrics.minWidth,
            "otherwise the split squeezes the page pane under the width the opening promise assumes")
    }
}

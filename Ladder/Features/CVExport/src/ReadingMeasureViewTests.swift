import AppKit
import SwiftUI
import Testing

@testable import Ladder

@MainActor
struct ReadingMeasureViewTests {
    @Test("[CVEXPORT-65] a phase is held to the reading measure unless it says otherwise")
    func theCapIsTheDefault() {
        let phase = ReadingMeasureView { EmptyView() }

        #expect(
            phase.cappedWidth == ReadingMeasure.width,
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
            ReadingMeasure.width < TailorFlowSheetMetrics.minWidth,
            "a measure as wide as the sheet caps nothing, and the centring has nothing to centre")
    }

    @Test("[CVEXPORT-65] a capped phase draws as a centred column, not against the leading edge")
    func theCappedPhaseIsCentred() throws {
        #expect(
            try drawsInk(spendsFullWidth: false, atX: Int(TailorFlowSheetMetrics.minWidth / 2)),
            "the capped column must still draw in the middle of the sheet")
        #expect(
            try !drawsInk(spendsFullWidth: false, atX: 10),
            """
            content reached the leading edge: either the cap is not applied at all, or it is \
            applied without the centring frame — the half [CVEXPORT-65] calls out as quiet
            """)
    }

    @Test("[CVEXPORT-65] the phase that declines the cap draws all the way to the edge")
    func theUncappedPhaseSpendsTheWidth() throws {
        #expect(
            try drawsInk(spendsFullWidth: true, atX: 10),
            "the CV preview must reach the sheet's edge, or [CVEXPORT-64]'s page pane shrinks")
    }

    /// Black on white rather than `Palette`, whose asset colours resolve through the app's
    /// `NSAppearance` and would tie the brightness cutoff to whichever appearance the suite
    /// runs in. The `.leading` alignment is load-bearing: a fixed `.frame(width:)` centres
    /// its child by default, which would hide a missing centring frame.
    private func drawsInk(spendsFullWidth: Bool, atX x: Int) throws -> Bool {
        let renderer = ImageRenderer(
            content: ReadingMeasureView(spendsFullWidth: spendsFullWidth) {
                Color.black.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: TailorFlowSheetMetrics.minWidth, height: 200, alignment: .leading)
            .background(Color.white))
        renderer.scale = 1

        let image = try #require(renderer.nsImage)
        let data = try #require(image.tiffRepresentation)
        let bitmap = try #require(NSBitmapImageRep(data: data))
        let pixel = try #require(bitmap.colorAt(x: x, y: 100)?.usingColorSpace(.deviceRGB))
        return pixel.brightnessComponent < 0.5
    }
}

import AppKit
import Testing

@testable import Ladder

@Suite struct PaletteTests {
    @Test(arguments: [
        "Paper", "PaperRaised", "Ink", "InkSoft", "Pine",
        "PineTint", "SummitGold", "Skyline", "Clay", "Mist",
    ])
    func colorAssetExists(named name: String) {
        #expect(NSColor(named: name) != nil, "Missing color asset: \(name)")
    }
}

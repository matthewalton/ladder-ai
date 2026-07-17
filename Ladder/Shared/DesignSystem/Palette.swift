import SwiftUI

// DESIGN.md §2 — the only way to reference color in views.
// Values live in Assets.xcassets with Daylight (light) / Night Hike (dark) variants.
extension Color {
    static let paper = Color("Paper")
    static let paperRaised = Color("PaperRaised")
    static let ink = Color("Ink")
    static let inkSoft = Color("InkSoft")
    static let pine = Color("Pine")
    static let pineTint = Color("PineTint")
    static let summitGold = Color("SummitGold")
    static let skyline = Color("Skyline")
    static let clay = Color("Clay")
    static let mist = Color("Mist")
}

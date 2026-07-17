import SwiftUI

// DESIGN.md §3 — SF Pro is the tool, New York is the story.
// UI chrome uses system text styles directly (.body, .headline, …);
// narrative text (journey, debriefs, fit-report prose, empty-state
// encouragement) uses `trailNarrative`. No `.custom` fonts, no hardcoded
// sizes outside the Summit View.
extension Font {
    /// New York serif for text that narrates the user's journey.
    static func trailNarrative(_ style: Font.TextStyle = .body) -> Font {
        .system(style, design: .serif)
    }
}

extension View {
    /// Elapsed times, dates, timeline metadata: monospaced digits so
    /// columns of timestamps align (DESIGN.md §3).
    func trailMetadata() -> some View {
        font(.caption)
            .monospacedDigit()
    }
}

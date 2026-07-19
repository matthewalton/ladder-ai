import SwiftUI

// No `.custom` fonts, no hardcoded sizes outside the Summit View.
extension Font {
    /// Serif for narrative text; UI chrome uses system text styles directly.
    static func trailNarrative(_ style: Font.TextStyle = .body) -> Font {
        .system(style, design: .serif)
    }
}

extension View {
    /// Monospaced digits so columns of timestamps align.
    func trailMetadata() -> some View {
        font(.caption)
            .monospacedDigit()
    }
}

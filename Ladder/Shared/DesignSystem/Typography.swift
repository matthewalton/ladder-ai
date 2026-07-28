import SwiftUI

extension Font {
    static func trailNarrative(_ style: Font.TextStyle = .body) -> Font {
        .system(style, design: .serif)
    }
}

extension View {
    func trailMetadata() -> some View {
        font(.caption)
            .monospacedDigit()
    }
}

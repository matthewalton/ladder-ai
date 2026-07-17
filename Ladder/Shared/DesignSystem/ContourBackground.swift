import SwiftUI

// DESIGN.md §4 — faint topographic contour lines, used in exactly two places:
// the journey celebration view and the empty states. Texture as reward, not
// wallpaper.
struct ContourBackground: View {
    var opacity: Double = 0.4

    var body: some View {
        Canvas { canvas, size in
            let bands = 7
            for band in 0..<bands {
                var path = Path()
                let baseY = size.height * Double(band + 1) / Double(bands + 1)
                let amplitude = 14.0 + Double(band % 3) * 8
                let wavelength = size.width / (2.2 + Double(band % 4) * 0.6)
                path.move(to: CGPoint(x: 0, y: baseY))
                var x = 0.0
                while x <= size.width {
                    let y = baseY + sin((x / wavelength) * .pi * 2 + Double(band) * 1.7) * amplitude
                    path.addLine(to: CGPoint(x: x, y: y))
                    x += 8
                }
                canvas.stroke(path, with: .color(.mist.opacity(opacity)), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
        .drawingGroup()
    }
}

#Preview {
    ContourBackground()
        .background(Color.paper)
}

import SwiftUI

/// Geometric badges inspired by painted trail markers. This file owns only
/// the geometry; the stage-kind mapping lives in the timeline slice.
enum Blaze: Equatable, Sendable {
    case circle
    case diamond
    case square
    case doubleChevron
    case flag
}

struct BlazeShape: Shape {
    var blaze: Blaze

    func path(in rect: CGRect) -> Path {
        switch blaze {
        case .circle:
            return Path(ellipseIn: rect)
        case .diamond:
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            path.closeSubpath()
            return path
        case .square:
            return Path(rect)
        case .doubleChevron:
            // Each chevron is a closed strip so the shape fills as well as
            // it strokes.
            var path = Path()
            let band = rect.height * 0.28
            for offset in [rect.minY, rect.minY + rect.height * 0.44] {
                path.move(to: CGPoint(x: rect.minX, y: offset + band))
                path.addLine(to: CGPoint(x: rect.midX, y: offset))
                path.addLine(to: CGPoint(x: rect.maxX, y: offset + band))
                path.addLine(to: CGPoint(x: rect.maxX, y: offset + band + rect.height * 0.14))
                path.addLine(to: CGPoint(x: rect.midX, y: offset + rect.height * 0.14))
                path.addLine(to: CGPoint(x: rect.minX, y: offset + band + rect.height * 0.14))
                path.closeSubpath()
            }
            return path
        case .flag:
            // A pole on the left, a pennant flying right.
            var path = Path()
            let poleWidth = rect.width * 0.14
            path.addRect(
                CGRect(x: rect.minX, y: rect.minY, width: poleWidth, height: rect.height))
            path.move(to: CGPoint(x: rect.minX + poleWidth, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.22))
            path.addLine(to: CGPoint(x: rect.minX + poleWidth, y: rect.minY + rect.height * 0.44))
            path.closeSubpath()
            return path
        }
    }
}

/// Filled marks completed stages; hollow marks future ones. The tint carries
/// the stage-kind accent where a caller maps one; pine is the default trail
/// color.
struct BlazeMark: View {
    var blaze: Blaze
    var filled: Bool
    var size: CGFloat = 14
    var tint: Color = .pine

    var body: some View {
        ZStack {
            if filled {
                BlazeShape(blaze: blaze)
                    .fill(tint)
            } else {
                BlazeShape(blaze: blaze)
                    .stroke(tint, lineWidth: 1.5)
                    .background(BlazeShape(blaze: blaze).fill(Color.paper))
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 16) {
        ForEach([Blaze.circle, .diamond, .square, .doubleChevron, .flag], id: \.self) { blaze in
            VStack(spacing: 8) {
                BlazeMark(blaze: blaze, filled: true)
                BlazeMark(blaze: blaze, filled: false)
            }
        }
    }
    .padding()
    .background(Color.paper)
}

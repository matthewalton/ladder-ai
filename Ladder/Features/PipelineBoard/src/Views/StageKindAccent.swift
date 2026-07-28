import SwiftUI

/// DESIGN.md §2: icon + chip tint only, never full-card fills; chip text
/// stays `ink` so every pairing clears contrast.
extension StageKind {
    var accent: Color {
        switch self {
        case .screen, .recruiter: .skyline
        case .technical, .systemDesign, .takeHome: .pine
        case .behavioral, .final, .other: .inkSoft
        case .offer: .summitGold
        }
    }

    var accentTint: Color {
        switch self {
        case .screen, .recruiter: Color.skyline.opacity(0.16)
        case .technical, .systemDesign, .takeHome: .pineTint
        case .behavioral, .final, .other: Color.mist.opacity(0.5)
        case .offer: Color.summitGold.opacity(0.18)
        }
    }
}

/// `mist`/`inkSoft` for a closed trail — never red.
extension ApplicationStatus {
    var chipForeground: Color {
        switch self {
        case .draft, .applied, .active: .pine
        case .offer: .ink
        case .rejected, .withdrawn: .inkSoft
        }
    }

    var chipBackground: Color {
        switch self {
        case .draft, .applied, .active: .pineTint
        case .offer: Color.summitGold.opacity(0.18)
        case .rejected, .withdrawn: Color.mist.opacity(0.5)
        }
    }
}

struct StageKindChip: View {
    var kind: StageKind

    var body: some View {
        HStack(spacing: 5) {
            BlazeMark(
                blaze: TimelineModel.blaze(for: kind), filled: true, size: 9,
                tint: kind.accent
            )
            Text(kind.label)
                .font(.caption)
                .foregroundStyle(Color.ink)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(kind.accentTint, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        ForEach(StageKind.knownCases, id: \.self) { kind in
            StageKindChip(kind: kind)
        }
    }
    .padding()
    .background(Color.paper)
}

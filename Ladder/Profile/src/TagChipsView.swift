import SwiftUI

/// Chips are the UI rendering of Tags (the `SkillTag` model). With an
/// `onRemove` handler each chip grows a remove control.
struct TagChipsView: View {
    let names: [String]
    var onRemove: ((String) -> Void)?

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), alignment: .leading)], alignment: .leading, spacing: 4) {
            ForEach(names, id: \.self) { name in
                HStack(spacing: 4) {
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(Color.ink)
                    if let onRemove {
                        Button {
                            onRemove(name)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(.caption2).weight(.bold))
                                .foregroundStyle(Color.inkSoft)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(name)")
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.pineTint, in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        TagChipsView(names: ["AI Engineering", "Agentic workflows", "Swift"])
        TagChipsView(names: ["Removable", "Chips"]) { _ in }
    }
    .padding()
    .background(Color.paper)
}

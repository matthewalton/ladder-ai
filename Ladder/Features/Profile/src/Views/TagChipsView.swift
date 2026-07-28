import SwiftUI

struct TagChipsView: View {
    let names: [String]
    var onRemove: ((String) -> Void)?
    var onTap: ((String) -> Void)?

    var body: some View {
        ChipFlowLayout(spacing: 6) {
            ForEach(names, id: \.self) { name in
                HStack(spacing: 5) {
                    if let onTap {
                        Button {
                            onTap(name)
                        } label: {
                            Text(name)
                                .font(.caption)
                                .foregroundStyle(Color.ink)
                                .fixedSize()
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Manage \(name)")
                    } else {
                        Text(name)
                            .font(.caption)
                            .foregroundStyle(Color.ink)
                            .fixedSize()
                    }
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

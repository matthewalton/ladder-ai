import SwiftUI

/// One brief bullet on the CV page — shared by the Experience and Projects
/// sections. Depth (tags, impact, notes) lives in the detail rail.
struct PointRowView: View {
    let achievement: Achievement
    let isFocused: Bool
    let onFocus: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    private var tagNames: [String] {
        Array(achievement.skills.map(\.name).sorted().prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•")
                    .foregroundStyle(Color.pine)
                Text(achievement.text)
                    .foregroundStyle(Color.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                RowDeleteButton(label: "Delete point", isVisible: isHovering, action: onDelete)
            }
            if !tagNames.isEmpty {
                HStack(spacing: 4) {
                    ForEach(tagNames, id: \.self) { name in
                        Text(name)
                            .font(.caption2)
                            .foregroundStyle(Color.inkSoft)
                            .fixedSize()
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.pineTint, in: RoundedRectangle(cornerRadius: 5))
                    }
                }
                .padding(.leading, 15)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            isFocused ? Color.paperRaised : Color.clear,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isFocused ? Color.pine : Color.clear, lineWidth: 2))
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture(perform: onFocus)
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Delete point", role: .destructive, action: onDelete)
        }
    }
}

/// The visible delete affordance shared by the CV page's rows — revealed on
/// hover so the page stays quiet, with the context menu as the secondary
/// path.
struct RowDeleteButton: View {
    let label: String
    let isVisible: Bool
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            Image(systemName: "trash")
                .font(.caption)
                .foregroundStyle(Color.clay)
        }
        .buttonStyle(.borderless)
        .help(label)
        .accessibilityLabel(label)
        .opacity(isVisible ? 1 : 0)
    }
}

#Preview {
    let store = try! ProfileStore(container: ProfileStore.container(inMemory: true))
    try! store.createProfile(name: "Alex Climber", headline: "Staff Engineer")
    let role = try! store.addRole(company: "Acme", title: "Senior Engineer", start: .now, end: nil)
    let focused = try! store.addAchievement(to: role, text: "Won the first internal AI Olympiad")
    try! store.tag(focused, skillNamed: "AI Engineering")
    let plain = try! store.addAchievement(to: role, text: "Cut CI build times 40%")
    return VStack(spacing: 4) {
        PointRowView(achievement: focused, isFocused: true, onFocus: {}, onDelete: {})
        PointRowView(achievement: plain, isFocused: false, onFocus: {}, onDelete: {})
    }
    .padding()
    .background(Color.paper)
}

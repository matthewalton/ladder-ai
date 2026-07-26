import SwiftUI

/// EXPERIENCE — roles inline on the page, newest first, each with its brief
/// points. Replaces the old roles sidebar.
struct ExperienceSectionView: View {
    @Bindable var store: ProfileStore
    let profile: Profile
    @Binding var focus: ProfileFocus?

    private var sortedRoles: [Role] {
        profile.roles.sorted { $0.start > $1.start }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ProfileSectionHeader(title: "Experience")
                Spacer()
                Button("Add role", systemImage: "plus", action: addRole)
                    .buttonStyle(.borderless)
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
            }

            if sortedRoles.isEmpty {
                Text("Every climb starts with a pack. Add your first role.")
                    .font(.trailNarrative(.title3))
                    .foregroundStyle(Color.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                ForEach(sortedRoles, id: \.persistentModelID) { role in
                    RoleDisclosureView(store: store, role: role, focus: $focus)
                }
            }
        }
    }

    private func addRole() {
        guard let role = try? store.addRole(company: "", title: "", start: .now, end: nil) else { return }
        focus = .role(role)
    }
}

private struct RoleDisclosureView: View {
    @Bindable var store: ProfileStore
    let role: Role
    @Binding var focus: ProfileFocus?

    @State private var isExpanded = true
    @State private var newPointText = ""
    @State private var isHovering = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            PointListView(
                store: store,
                points: role.orderedAchievements,
                parentToken: "role-\(String(describing: role.persistentModelID))",
                focus: $focus,
                onMove: { source, destination in
                    try? store.moveAchievements(in: role, from: source, to: destination)
                }
            )
            .padding(.leading, 4)

            PageAddField(
                prompt: "Add a point — a brief key talking point",
                text: $newPointText,
                onSubmit: addPoint
            )
            .padding(.leading, 20)
            .padding(.top, 4)
        } label: {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(role.title.isEmpty ? "New role" : role.title)
                        .font(.headline)
                        .foregroundStyle(Color.ink)
                    Text(role.company.isEmpty ? "Company" : role.company)
                        .font(.caption)
                        .foregroundStyle(Color.inkSoft)
                }
                Spacer()
                Text(profileDateRange(start: role.start, end: role.end))
                    .trailMetadata()
                    .foregroundStyle(Color.inkSoft)
                RowDeleteButton(label: "Delete role", isVisible: isHovering, action: deleteRole)
            }
            .contentShape(Rectangle())
            .onTapGesture { focus = .role(role) }
            .onHover { isHovering = $0 }
            .contextMenu {
                Button("Edit role") { focus = .role(role) }
                Button("Delete role", role: .destructive, action: deleteRole)
            }
        }
    }

    private func addPoint() {
        let text = newPointText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        try? store.addAchievement(to: role, text: text)
        newPointText = ""
    }

    private func deleteRole() {
        // Focus follows deletion: clear it for the role or any of its points.
        switch focus {
        case .role(let focused) where focused == role:
            focus = nil
        case .point(let point) where point.role == role:
            focus = nil
        default:
            break
        }
        try? store.deleteRole(role)
    }
}

/// The reorderable point list for a role's achievements. Drags carry a
/// parent-scoped token so a drop from another list is rejected.
struct PointListView: View {
    @Bindable var store: ProfileStore
    let points: [Achievement]
    let parentToken: String
    @Binding var focus: ProfileFocus?
    let onMove: (IndexSet, Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(points.enumerated()), id: \.element.persistentModelID) { index, point in
                PointRowView(
                    achievement: point,
                    isFocused: focus == .point(point),
                    onFocus: { focus = .point(point) },
                    onDelete: { delete(point) }
                )
                .draggable("\(parentToken):\(index)")
                .dropDestination(for: String.self) { items, _ in
                    drop(items, insertBefore: index)
                }
                .contextMenu {
                    Button("Move up") { onMove(IndexSet(integer: index), max(index - 1, 0)) }
                        .disabled(index == 0)
                    Button("Move down") { onMove(IndexSet(integer: index), min(index + 2, points.count)) }
                        .disabled(index == points.count - 1)
                    Button("Delete point", role: .destructive) { delete(point) }
                }
            }
        }
    }

    private func delete(_ point: Achievement) {
        if focus == .point(point) { focus = nil }
        try? store.deleteAchievement(point)
    }

    private func drop(_ items: [String], insertBefore destination: Int) -> Bool {
        guard let item = items.first,
            item.hasPrefix("\(parentToken):"),
            let source = Int(item.dropFirst("\(parentToken):".count)),
            points.indices.contains(source)
        else { return false }
        // `move(fromOffsets:toOffset:)` semantics: destination is the
        // insert-before position in the pre-move array.
        onMove(IndexSet(integer: source), source < destination ? destination + 1 : destination)
        return true
    }
}

#Preview {
    let store = try! ProfileStore(container: ProfileStore.container(inMemory: true))
    let profile = try! store.createProfile(name: "Alex Climber", headline: "Staff Engineer")
    let role = try! store.addRole(company: "Acme", title: "Senior Engineer", start: .now, end: nil)
    let point = try! store.addAchievement(to: role, text: "Won the first internal AI Olympiad")
    try! store.tag(point, skillNamed: "AI Engineering")
    try! store.addAchievement(to: role, text: "Cut CI build times 40%")
    return ExperienceSectionView(store: store, profile: profile, focus: .constant(.point(point)))
        .padding()
        .background(Color.paper)
        .frame(width: 640)
}

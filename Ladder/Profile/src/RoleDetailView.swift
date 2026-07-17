import SwiftUI

/// Content pane: the selected role's achievements, in their persisted drag
/// order. Reorder and inspector arrive with their criteria.
struct RoleDetailView: View {
    @Bindable var store: ProfileStore
    let role: Role

    @State private var newAchievementText = ""
    @State private var selectedAchievement: Achievement?

    var body: some View {
        List(selection: $selectedAchievement) {
            ForEach(role.orderedAchievements, id: \.persistentModelID) { achievement in
                Text(achievement.text)
                    .padding(.vertical, 2)
                    .tag(achievement)
            }
            .onMove { source, destination in
                try? store.moveAchievements(in: role, from: source, to: destination)
            }
        }
        .inspector(isPresented: .constant(selectedAchievement != nil)) {
            if let achievement = selectedAchievement {
                AchievementInspectorView(store: store, achievement: achievement)
                    .id(achievement.persistentModelID)
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                TextField("New achievement", text: $newAchievementText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addAchievement)
                Button("Add", action: addAchievement)
                    .disabled(newAchievementText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(8)
            .background(.bar)
        }
        .navigationTitle(role.title)
        .navigationSubtitle(role.company)
    }

    private func addAchievement() {
        let text = newAchievementText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        try? store.addAchievement(to: role, text: text)
        newAchievementText = ""
    }
}

#Preview {
    let store = try! ProfileStore(container: ProfileStore.container(inMemory: true))
    try! store.createProfile(name: "Alex Climber", headline: "Staff Engineer")
    let role = try! store.addRole(company: "Acme", title: "Senior Engineer", start: .now, end: nil)
    try! store.addAchievement(to: role, text: "Cut build times 40%")
    return RoleDetailView(store: store, role: role)
}

import SwiftUI

struct RoleDetailView: View {
    @Bindable var store: ProfileStore
    let role: Role

    @State private var newAchievementText = ""
    @State private var selectedAchievement: Achievement?

    var body: some View {
        List(selection: $selectedAchievement) {
            ForEach(role.orderedAchievements, id: \.persistentModelID) { achievement in
                // paperRaised card + mist hairline (DESIGN.md §4); selection
                // reads as a pine border, so the row's own highlight is
                // covered by an opaque paper row background.
                Text(achievement.text)
                    .foregroundStyle(Color.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(
                        Color.paperRaised,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                selectedAchievement == achievement ? Color.pine : Color.mist,
                                lineWidth: selectedAchievement == achievement ? 2 : 1))
                    .tag(achievement)
                    .listRowBackground(Color.paper)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
            }
            .onMove { source, destination in
                try? store.moveAchievements(in: role, from: source, to: destination)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.paper)
        .overlay {
            if role.orderedAchievements.isEmpty {
                Text("What did you move forward here? Add the first achievement below.")
                    .font(.trailNarrative(.title3))
                    .foregroundStyle(Color.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background {
                        ContourBackground()
                            .background(Color.paper)
                    }
                    .allowsHitTesting(false)
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

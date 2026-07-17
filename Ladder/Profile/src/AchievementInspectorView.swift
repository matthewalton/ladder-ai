import SwiftUI

/// Inspector pane: details of the selected achievement — canonical text,
/// impact metric, tech, strength notes, and skill chips.
struct AchievementInspectorView: View {
    @Bindable var store: ProfileStore
    let achievement: Achievement

    @State private var text: String
    @State private var newSkill = ""

    init(store: ProfileStore, achievement: Achievement) {
        self.store = store
        self.achievement = achievement
        _text = State(initialValue: achievement.text)
    }

    var body: some View {
        Form {
            Section("Achievement") {
                TextField("Achievement", text: $text, axis: .vertical)
                    .lineLimit(3...8)
                    .onSubmit(commitText)
                if text != achievement.text {
                    Button("Save wording", action: commitText)
                }
            }

            Section("Skills") {
                if !achievement.skills.isEmpty {
                    SkillChipsView(names: achievement.skills.map(\.name).sorted())
                }
                TextField("Add a skill", text: $newSkill)
                    .onSubmit(addSkill)
            }
        }
        .formStyle(.grouped)
    }

    private func commitText() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            text = achievement.text
            return
        }
        try? store.updateAchievementText(achievement, to: trimmed)
        text = achievement.text
    }

    private func addSkill() {
        let name = newSkill.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        try? store.tag(achievement, skillNamed: name)
        newSkill = ""
    }
}

/// Skill chips: pineTint fills, 6pt radius (DESIGN.md §2, §4).
struct SkillChipsView: View {
    let names: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), alignment: .leading)], alignment: .leading, spacing: 4) {
            ForEach(names, id: \.self) { name in
                Text(name)
                    .font(.caption)
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.pineTint, in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}

#Preview {
    let store = try! ProfileStore(container: ProfileStore.container(inMemory: true))
    try! store.createProfile(name: "Alex Climber", headline: "Staff Engineer")
    let role = try! store.addRole(company: "Acme", title: "Senior Engineer", start: .now, end: nil)
    let achievement = try! store.addAchievement(to: role, text: "Cut build times 40%")
    try! store.tag(achievement, skillNamed: "Swift")
    return AchievementInspectorView(store: store, achievement: achievement)
}

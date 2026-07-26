import SwiftUI

/// The tag manage sheet (CONTEXT.md; decisions/0013): curates the one shared
/// Tag a chip names — recase the primary name, record or remove Aliases.
/// Never a rename, never a merge — those wait for the pool manager view.
struct TagManageSheet: View {
    @Bindable var store: ProfileStore
    let tag: SkillTag

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var newAlias = ""
    @State private var message: String?

    init(store: ProfileStore, tag: SkillTag) {
        self.store = store
        self.tag = tag
        _name = State(initialValue: tag.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(tag.name)
                .font(.headline)
                .foregroundStyle(Color.ink)

            VStack(alignment: .leading, spacing: 6) {
                Text("Primary name — curate the casing")
                    .font(.caption)
                    .foregroundStyle(Color.inkSoft)
                HStack {
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(recase)
                    Button("Save", action: recase)
                        .disabled(name == tag.name)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Aliases — matching only, never shown on a chip")
                    .font(.caption)
                    .foregroundStyle(Color.inkSoft)
                if tag.aliases.isEmpty {
                    Text("No aliases yet.")
                        .font(.caption)
                        .foregroundStyle(Color.inkSoft)
                }
                ForEach(tag.aliases, id: \.self) { alias in
                    HStack {
                        Text(alias)
                            .font(.body.monospaced())
                            .foregroundStyle(Color.ink)
                        Spacer()
                        Button {
                            try? store.removeAlias(alias, from: tag)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(.caption2).weight(.bold))
                                .foregroundStyle(Color.inkSoft)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove alias \(alias)")
                    }
                }
                HStack {
                    TextField("Add an alias, e.g. k8s", text: $newAlias)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addAlias)
                    Button("Add", action: addAlias)
                        .disabled(newAlias.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Color.clay)
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 340)
        .background(Color.paper)
    }

    private func recase() {
        do {
            try store.recaseTag(tag, to: name)
            message = nil
        } catch ProfileStoreError.renameBeyondRecase {
            message = "Only the casing can change here — a different name is a merge, and merges wait for the pool manager."
            name = tag.name
        } catch {
            message = "Could not save the name."
        }
    }

    private func addAlias() {
        let alias = newAlias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !alias.isEmpty else { return }
        do {
            try store.recordAlias(alias, on: tag)
            newAlias = ""
            message = nil
        } catch ProfileStoreError.aliasAlreadyInUse {
            message = "“\(alias.lowercased())” already matches a tag — one name, one tag."
        } catch {
            message = "Could not record the alias."
        }
    }
}

#Preview {
    let store = try! ProfileStore(container: ProfileStore.container(inMemory: true))
    try! store.createProfile(name: "Alex Climber", headline: "Staff Engineer")
    let role = try! store.addRole(company: "Acme", title: "Senior Engineer", start: .now, end: nil)
    let point = try! store.addAchievement(to: role, text: "Ran the cluster")
    let tag = try! store.tag(point, skillNamed: "Kubernetes")
    try! store.recordAlias("k8s", on: tag)
    return TagManageSheet(store: store, tag: tag)
}

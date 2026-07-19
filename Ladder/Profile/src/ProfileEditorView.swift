import SwiftUI

struct ProfileEditorView: View {
    @Bindable var store: ProfileStore

    @State private var selectedRole: Role?
    @State private var isAddingRole = false
    @State private var isImportingCV = false
    @State private var isTailoring = false

    private var sortedRoles: [Role] {
        (store.profile?.roles ?? []).sorted { $0.start > $1.start }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedRole) {
                Section {
                    ForEach(sortedRoles, id: \.persistentModelID) { role in
                        RoleRowView(role: role)
                            .tag(role)
                            .contextMenu {
                                Button("Delete role", role: .destructive) {
                                    if selectedRole == role { selectedRole = nil }
                                    try? store.deleteRole(role)
                                }
                            }
                    }
                } header: {
                    if let profile = store.profile {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name)
                                .font(.headline)
                                .foregroundStyle(Color.ink)
                            if !profile.headline.isEmpty {
                                Text(profile.headline)
                                    .font(.caption)
                                    .foregroundStyle(Color.inkSoft)
                            }
                        }
                        .padding(.bottom, 4)
                    }
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem {
                    Button("Add role", systemImage: "plus") {
                        isAddingRole = true
                    }
                }
                ToolbarItem {
                    Button("Import CV", systemImage: "arrow.down.document") {
                        isImportingCV = true
                    }
                }
                ToolbarItem {
                    Button("Tailor", systemImage: "scissors") {
                        isTailoring = true
                    }
                }
            }
        } detail: {
            if let role = selectedRole {
                RoleDetailView(store: store, role: role)
            } else {
                Text("Select a role to see its achievements.")
                    .font(.trailNarrative(.title3))
                    .foregroundStyle(Color.inkSoft)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.paper)
            }
        }
        .sheet(isPresented: $isAddingRole) {
            RoleFormView(store: store)
        }
        .sheet(isPresented: $isImportingCV) {
            ImportCVView(profileStore: store)
        }
        .sheet(isPresented: $isTailoring) {
            TailorView(profileStore: store)
        }
    }
}

private struct RoleRowView: View {
    let role: Role

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(role.title)
                .font(.body)
            Text(role.company)
                .font(.caption)
                .foregroundStyle(Color.inkSoft)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    let store = try! ProfileStore(container: ProfileStore.container(inMemory: true))
    try! store.createProfile(name: "Alex Climber", headline: "Staff Engineer")
    try! store.addRole(company: "Acme", title: "Senior Engineer", start: .now, end: nil)
    return ProfileEditorView(store: store)
}

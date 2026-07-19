import SwiftUI

struct AddFirstRoleView: View {
    @Bindable var store: ProfileStore
    @State private var isAddingRole = false
    @State private var isImportingCV = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Every climb starts with a pack. Add your first role.")
                .font(.trailNarrative(.title2))
                .foregroundStyle(Color.inkSoft)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("Add role") {
                    isAddingRole = true
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.pine)

                Button("Import CV") {
                    isImportingCV = true
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ContourBackground()
                .background(Color.paper)
        }
        .sheet(isPresented: $isAddingRole) {
            RoleFormView(store: store)
        }
        .sheet(isPresented: $isImportingCV) {
            ImportCVView(profileStore: store)
        }
    }
}

#Preview {
    let store = try! ProfileStore(container: ProfileStore.container(inMemory: true))
    try! store.createProfile(name: "Alex Climber", headline: "Staff Engineer")
    return AddFirstRoleView(store: store)
}

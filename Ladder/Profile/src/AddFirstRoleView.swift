import SwiftUI

/// The add-first-role empty state: an existing Profile with zero roles
/// (SPEC.md [PROFILE-10]). Copy per DESIGN.md §6; the Import CV action
/// arrives with the cv-import slice, not here.
struct AddFirstRoleView: View {
    @Bindable var store: ProfileStore
    @State private var isAddingRole = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Every climb starts with a pack. Add your first role.")
                .font(.trailNarrative(.title2))
                .foregroundStyle(Color.inkSoft)
                .multilineTextAlignment(.center)

            Button("Add role") {
                isAddingRole = true
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.pine)
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
    }
}

#Preview {
    let store = try! ProfileStore(container: ProfileStore.container(inMemory: true))
    try! store.createProfile(name: "Alex Climber", headline: "Staff Engineer")
    return AddFirstRoleView(store: store)
}

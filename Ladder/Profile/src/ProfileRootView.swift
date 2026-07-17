import SwiftData
import SwiftUI

/// Entry point of the Profile slice: presents exactly one of the
/// create-profile empty state, the add-first-role empty state, or the editor
/// (SPEC.md [PROFILE-2], [PROFILE-10]).
struct ProfileRootView: View {
    @Bindable var store: ProfileStore

    var body: some View {
        switch store.presentation {
        case .createProfile:
            CreateProfileView(store: store)
        case .addFirstRole:
            AddFirstRoleView(store: store)
        case .editor:
            ProfileEditorView(store: store)
        }
    }
}

#Preview("Create profile") {
    let store = try! ProfileStore(container: ProfileStore.container(inMemory: true))
    return ProfileRootView(store: store)
}

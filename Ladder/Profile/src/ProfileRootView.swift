import SwiftData
import SwiftUI

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

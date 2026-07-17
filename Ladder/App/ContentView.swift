import SwiftUI

/// App shell. Phase 1: the Profile slice owns the window.
struct ContentView: View {
    @Bindable var store: ProfileStore

    var body: some View {
        ProfileRootView(store: store)
    }
}

#Preview {
    let store = try! ProfileStore(container: ProfileStore.container(inMemory: true))
    return ContentView(store: store)
}

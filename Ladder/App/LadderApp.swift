import SwiftData
import SwiftUI

@main
struct LadderApp: App {
    private let store: ProfileStore

    init() {
        do {
            store = try ProfileStore(container: ProfileStore.container())
            try store.load()
        } catch {
            fatalError("Failed to open the Ladder store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
    }
}

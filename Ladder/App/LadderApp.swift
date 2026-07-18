import SwiftData
import SwiftUI

@main
struct LadderApp: App {
    private let store: ProfileStore
    private let pipelineStore: PipelineStore

    init() {
        do {
            store = try ProfileStore(container: ProfileStore.container())
            try store.load()
            // Same container, own context (ProfileStore's exposed-container
            // seam); load() runs the applied-date backfill ([PIPEBOARD-8]).
            pipelineStore = PipelineStore(container: store.container)
            try pipelineStore.load()
        } catch {
            fatalError("Failed to open the Ladder store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store, pipelineStore: pipelineStore)
        }
        Settings {
            SettingsView()
        }
    }
}

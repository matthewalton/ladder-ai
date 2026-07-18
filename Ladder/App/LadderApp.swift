import SwiftData
import SwiftUI

@main
struct LadderApp: App {
    private let store: ProfileStore
    private let pipelineStore: PipelineStore
    private let calendarStore: CalendarSyncStore

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
        let service = EventKitCalendarSyncService()
        calendarStore = CalendarSyncStore(pipeline: pipelineStore, service: service)
        calendarStore.startObservingChanges()
        // Launch never prompts (CalendarSync decisions/0001): scan only when
        // access is already granted; the bar's check action is the explicit
        // gesture that first requests it.
        let calendarStore = calendarStore
        Task { @MainActor in
            if await service.accessState() == .granted {
                await calendarStore.scan()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                store: store, pipelineStore: pipelineStore, calendarStore: calendarStore
            )
        }
        Settings {
            SettingsView()
        }
    }
}

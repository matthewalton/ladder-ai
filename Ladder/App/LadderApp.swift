import SwiftData
import SwiftUI

@main
struct LadderApp: App {
    private let store: ProfileStore
    private let pipelineStore: PipelineStore
    private let calendarStore: CalendarSyncStore
    private let recorderStore: RecorderStore

    init() {
        do {
            store = try ProfileStore(container: ProfileStore.container())
            try store.load()
            // load() runs the applied-date backfill.
            pipelineStore = PipelineStore(container: store.container)
            try pipelineStore.load()
        } catch {
            fatalError("Failed to open the Ladder store: \(error)")
        }
        recorderStore = RecorderStore(service: AVAudioEngineCaptureService())
        let service = EventKitCalendarSyncService()
        calendarStore = CalendarSyncStore(pipeline: pipelineStore, service: service)
        calendarStore.startObservingChanges()
        // Launch never prompts: scan only when access is already granted.
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
        MenuBarExtra {
            RecorderPopoverView(store: recorderStore)
        } label: {
            Image(systemName: recorderStore.menuBarSymbolName)
        }
        .menuBarExtraStyle(.window)
    }
}

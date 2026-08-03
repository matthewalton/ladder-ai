import SwiftData
import SwiftUI

@main
struct LadderApp: App {
    private let store: ProfileStore
    private let pipelineStore: PipelineStore
    private let calendarStore: CalendarSyncStore

    private static func scratchStoreURL() throws -> URL {
        let directory = URL.temporaryDirectory.appending(
            path: "LadderUITests", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "Ladder.store")
    }

    init() {
        do {
            let storeURL = TourMode.isActive ? try Self.scratchStoreURL() : nil
            let container = try ProfileStore.container(at: storeURL)
            if TourMode.isActive {
                if TourSeed.isRequested {
                    try TourSeed.plant(in: container)
                } else if TourSeed.isBareRequested {
                    try TourSeed.plantBare(in: container)
                }
            }
            store = ProfileStore(container: container)
            try store.load()
            pipelineStore = PipelineStore(container: store.container)
            try pipelineStore.load()
        } catch {
            fatalError("Failed to open the Ladder store: \(error)")
        }
        let service: any CalendarSyncService =
            TourMode.isActive
            ? FixtureCalendarSyncService(events: TourSeed.isRequested ? TourSeed.calendarEvents() : [])
            : EventKitCalendarSyncService()
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
        WindowGroup(id: GranolaNotesWindow.windowID, for: PersistentIdentifier.self) { $transcriptID in
            if let transcriptID {
                GranolaNotesWindow(container: store.container, transcriptID: transcriptID)
            }
        }
        WindowGroup(id: JobDescriptionWindow.windowID, for: PersistentIdentifier.self) { $applicationID in
            if let applicationID {
                JobDescriptionWindow(store: pipelineStore, applicationID: applicationID)
            }
        }
        WindowGroup(id: NotesEditWindow.windowID, for: PersistentIdentifier.self) { $applicationID in
            if let applicationID {
                NotesEditWindow(store: pipelineStore, applicationID: applicationID)
            }
        }
        WindowGroup(id: PrepContextEditWindow.windowID, for: PersistentIdentifier.self) { $stageID in
            if let stageID {
                PrepContextEditWindow(store: pipelineStore, stageID: stageID)
            }
        }
        WindowGroup(id: DebriefWindow.windowID, for: PersistentIdentifier.self) { $debriefID in
            if let debriefID {
                DebriefWindow(container: store.container, debriefID: debriefID)
            }
        }
        WindowGroup(id: PrepPackWindow.windowID, for: PersistentIdentifier.self) { $packID in
            if let packID {
                PrepPackWindow(container: store.container, packID: packID)
            }
        }
    }
}

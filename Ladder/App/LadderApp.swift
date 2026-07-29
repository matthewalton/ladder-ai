import SwiftData
import SwiftUI

@main
struct LadderApp: App {
    private let store: ProfileStore
    private let pipelineStore: PipelineStore
    private let calendarStore: CalendarSyncStore

    /// UI tests drive this same app, so they launch it onto a throwaway store
    /// and canned calendar — never the human's own (ADR 0004).
    private static var isDrivenByUITest: Bool {
        ProcessInfo.processInfo.arguments.contains("-LadderScratchStore")
    }

    private static func scratchStoreURL() throws -> URL {
        let directory = URL.temporaryDirectory.appending(
            path: "LadderUITests", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "Ladder.store")
    }

    init() {
        do {
            let storeURL = Self.isDrivenByUITest ? try Self.scratchStoreURL() : nil
            store = try ProfileStore(container: ProfileStore.container(at: storeURL))
            try store.load()
            pipelineStore = PipelineStore(container: store.container)
            try pipelineStore.load()
        } catch {
            fatalError("Failed to open the Ladder store: \(error)")
        }
        let service: any CalendarSyncService =
            Self.isDrivenByUITest ? FixtureCalendarSyncService() : EventKitCalendarSyncService()
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

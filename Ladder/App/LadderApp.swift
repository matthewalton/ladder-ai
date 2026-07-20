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
            // load() runs the applied-date backfill.
            pipelineStore = PipelineStore(container: store.container)
            try pipelineStore.load()
        } catch {
            fatalError("Failed to open the Ladder store: \(error)")
        }
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
        // The notes window (TranscriptImport decisions/0007): the Stage only
        // indicates attached notes; reading them opens here.
        WindowGroup(id: GranolaNotesWindow.windowID, for: PersistentIdentifier.self) { $transcriptID in
            if let transcriptID {
                GranolaNotesWindow(container: store.container, transcriptID: transcriptID)
            }
        }
        // The collapsed-content windows (docs/adr/0003): forms only indicate
        // long text content is set; reading — or, for the typed-only fields,
        // editing — opens here.
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

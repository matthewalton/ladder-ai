import SwiftData
import SwiftUI

/// The editable windows of the docs/adr/0003 pattern ([PIPEBOARD-32]):
/// typing is the only input path for the notes and the prep context, so —
/// unlike the read-only job description window — these edit, autosaving
/// through the store's existing seams, never a private write path.
struct NotesEditWindow: View {
    static let windowID = "application-notes"

    var store: PipelineStore
    var applicationID: PersistentIdentifier

    @State private var text = ""
    @State private var loaded = false
    @State private var saveFailed = false

    private var application: Application? { store.application(for: applicationID) }

    var body: some View {
        Group {
            if let application {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes — \(application.company)")
                        .font(.trailNarrative(.title3))
                        .foregroundStyle(Color.ink)
                    TextEditor(text: $text)
                        .font(.callout)
                        .scrollContentBackground(.hidden)
                    if saveFailed {
                        Text("Saving the notes failed.")
                            .font(.callout)
                            .foregroundStyle(Color.clay)
                    }
                }
                .padding(20)
                .background(Color.paper)
                .onAppear {
                    if !loaded {
                        text = application.notes
                        loaded = true
                    }
                }
                .onChange(of: text) {
                    if text != application.notes { save(text) }
                }
            } else {
                Text("This application is no longer here.")
                    .font(.callout)
                    .foregroundStyle(Color.inkSoft)
                    .padding(40)
            }
        }
        .frame(minWidth: 420, minHeight: 320)
    }

    /// Autosave through `updateDetails` — the [PIPEBOARD-12] seam.
    func save(_ newText: String) {
        guard let application else { return }
        do {
            try store.updateDetails(
                application,
                source: application.source,
                notes: newText,
                appliedAt: application.appliedAt,
                jobDescription: application.jobDescription
            )
            saveFailed = false
        } catch {
            saveFailed = true
        }
    }
}

/// The prep context's editable window — the Stage-side twin of
/// `NotesEditWindow`.
struct PrepContextEditWindow: View {
    static let windowID = "stage-prep-context"

    var store: PipelineStore
    var stageID: PersistentIdentifier

    @State private var text = ""
    @State private var loaded = false
    @State private var saveFailed = false

    private var stage: Stage? { store.stage(for: stageID) }

    var body: some View {
        Group {
            if let stage {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Prep context — \(stage.kind.label)")
                        .font(.trailNarrative(.title3))
                        .foregroundStyle(Color.ink)
                    TextEditor(text: $text)
                        .font(.callout)
                        .scrollContentBackground(.hidden)
                    if saveFailed {
                        Text("Saving the prep context failed.")
                            .font(.callout)
                            .foregroundStyle(Color.clay)
                    }
                }
                .padding(20)
                .background(Color.paper)
                .onAppear {
                    if !loaded {
                        text = stage.prepContext
                        loaded = true
                    }
                }
                .onChange(of: text) {
                    if text != stage.prepContext { save(text) }
                }
            } else {
                Text("This stage is no longer here.")
                    .font(.callout)
                    .foregroundStyle(Color.inkSoft)
                    .padding(40)
            }
        }
        .frame(minWidth: 420, minHeight: 320)
    }

    /// Autosave through `updateStage` — the [PIPEBOARD-15] seam; every other
    /// Stage field is passed back unchanged.
    func save(_ newText: String) {
        guard let stage else { return }
        do {
            try store.updateStage(
                stage,
                kind: stage.kind,
                scheduledAt: stage.scheduledAt,
                outcome: stage.outcome,
                heardBackAt: stage.heardBackAt,
                prepContext: newText,
                meetingURL: stage.meetingURL
            )
            saveFailed = false
        } catch {
            saveFailed = true
        }
    }
}

#Preview("Notes") {
    let store = try! PipelineStore(container: ProfileStore.container(inMemory: true))
    let context = ModelContext(store.container)
    let application = Application(
        company: "Summit Labs", roleTitle: "Platform Engineer",
        jobDescription: "", status: .active, notes: "Warm intro via Sam.")
    context.insert(application)
    try! context.save()
    return NotesEditWindow(store: store, applicationID: application.persistentModelID)
}

#Preview("Prep context") {
    let store = try! PipelineStore(container: ProfileStore.container(inMemory: true))
    let context = ModelContext(store.container)
    let stage = Stage(kind: .technical, prepContext: "Panel of three; whiteboard likely.")
    context.insert(stage)
    try! context.save()
    return PrepContextEditWindow(store: store, stageID: stage.persistentModelID)
}

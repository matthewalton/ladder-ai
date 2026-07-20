import SwiftData
import SwiftUI

/// The Granola notes section of the Stage form (decisions/0007): a link
/// field with a one-step attach, and — once attached — an indicator row,
/// never the full notes inline. Reading opens the notes window.
struct GranolaNotesSection: View {
    var container: ModelContainer
    var stage: Stage

    @State private var store: GranolaNotesStore
    @State private var linkText = ""
    @State private var isAttaching = false
    @State private var failureMessage: String?
    @Environment(\.openWindow) private var openWindow

    init(container: ModelContainer, stage: Stage) {
        self.container = container
        self.stage = stage
        _store = State(initialValue: GranolaNotesStore(container: container))
    }

    var body: some View {
        Section("Granola notes") {
            if let transcript = stage.transcript {
                HStack {
                    Label {
                        Text("Notes attached — \(transcript.recordedAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.callout)
                            .foregroundStyle(Color.ink)
                    } icon: {
                        Image(systemName: "note.text")
                            .foregroundStyle(Color.pine)
                    }
                    Spacer()
                    Button("Open") {
                        openWindow(id: GranolaNotesWindow.windowID, value: transcript.persistentModelID)
                    }
                    Button("Remove") { remove() }
                }
                Text("Paste a new link to replace the notes.")
                    .font(.callout)
                    .foregroundStyle(Color.inkSoft)
            } else {
                Text("Paste the call's Granola share link to attach its notes.")
                    .font(.callout)
                    .foregroundStyle(Color.inkSoft)
            }
            HStack {
                TextField("https://notes.granola.ai/t/…", text: $linkText)
                    .textFieldStyle(.roundedBorder)
                Button(isAttaching ? "Attaching…" : "Attach") { attach() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.pine)
                    .disabled(
                        isAttaching
                            || linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let failureMessage {
                Text(failureMessage)
                    .font(.callout)
                    .foregroundStyle(Color.clay)
            }
        }
    }

    private func attach() {
        failureMessage = nil
        isAttaching = true
        Task {
            defer { isAttaching = false }
            do {
                try await store.attachNotes(fromLinkText: linkText, to: stage, importedAt: .now)
                linkText = ""
            } catch GranolaShareError.notAShareLink {
                failureMessage = "That's not a Granola share link — it looks like notes.granola.ai/t/…"
            } catch GranolaShareError.noSharedDocument {
                failureMessage = "That link doesn't look like a Granola share page."
            } catch {
                failureMessage = "Fetching the notes failed — check the connection and try again."
            }
        }
    }

    private func remove() {
        failureMessage = nil
        do {
            try store.removeNotes(from: stage)
        } catch {
            failureMessage = "Removing the notes failed."
        }
    }
}

#Preview {
    let container = try! ProfileStore.container(inMemory: true)
    let stage = Stage(kind: .technical)
    ModelContext(container).insert(stage)
    return Form {
        GranolaNotesSection(container: container, stage: stage)
    }
    .formStyle(.grouped)
    .frame(width: 460)
}

import SwiftData
import SwiftUI

/// The separate window showing a Stage's full notes overview — the Stage
/// itself only indicates that notes are attached (decisions/0007).
struct GranolaNotesWindow: View {
    static let windowID = "granola-notes"

    var container: ModelContainer
    var transcriptID: PersistentIdentifier

    private var transcript: Transcript? {
        ModelContext(container).model(for: transcriptID) as? Transcript
    }

    var body: some View {
        Group {
            if let transcript, let notes = transcript.notesSummary {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Granola notes — \(transcript.recordedAt.formatted(date: .long, time: .omitted))")
                            .font(.trailNarrative(.title3))
                            .foregroundStyle(Color.ink)
                        Text(notes)
                            .font(.callout)
                            .foregroundStyle(Color.ink)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(20)
                }
                .background(Color.paper)
            } else {
                Text("These notes are no longer attached.")
                    .font(.callout)
                    .foregroundStyle(Color.inkSoft)
                    .padding(40)
            }
        }
        .frame(minWidth: 420, minHeight: 320)
    }
}

#Preview {
    let container = try! ProfileStore.container(inMemory: true)
    let context = ModelContext(container)
    let transcript = Transcript(
        recordedAt: .now,
        notesSummary: "## Interview Format and Setup\n- Technical coding challenge via CodeSignal"
    )
    context.insert(transcript)
    try! context.save()
    return GranolaNotesWindow(container: container, transcriptID: transcript.persistentModelID)
}

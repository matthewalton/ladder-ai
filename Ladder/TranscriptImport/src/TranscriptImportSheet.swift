import SwiftData
import SwiftUI

/// Paste → parse → preview → confirm (decisions/0004). Nothing lands on the
/// Stage until the confirm; cancelling writes nothing ([TRANSCRIPT-13]).
struct TranscriptImportSheet: View {
    var store: TranscriptImportStore
    var stage: Stage
    /// Pre-filled when a file drop opened the sheet ([TRANSCRIPT-11]).
    var initialText: String = ""
    @Environment(\.dismiss) private var dismiss

    @State private var transcriptText: String
    @State private var notesOverview = ""
    @State private var preview: TranscriptImportPreview?
    @State private var failureMessage: String?
    @State private var isFetching = false
    /// The [TRANSCRIPT-25] fallback, set by a share-link fetch.
    @State private var suggestedImportDate: Date?
    @State private var linkHasNoTranscript = false

    init(store: TranscriptImportStore, stage: Stage, initialText: String = "") {
        self.store = store
        self.stage = stage
        self.initialText = initialText
        _transcriptText = State(initialValue: initialText)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Transcript") {
                    TextEditor(text: $transcriptText)
                        .font(.callout)
                        .frame(minHeight: 120)
                    Text("Paste the transcript text — or just a notes.granola.ai share link, and Preview will fetch it.")
                        .font(.callout)
                        .foregroundStyle(Color.inkSoft)
                }
                Section("Notes overview (optional)") {
                    TextEditor(text: $notesOverview)
                        .font(.callout)
                        .frame(minHeight: 60)
                }
                if let preview {
                    Section("Preview") {
                        if linkHasNoTranscript {
                            Label(
                                "This link carries no transcript — notes only. Share it with the transcript included, or paste the transcript text.",
                                systemImage: "info.circle"
                            )
                            .font(.callout)
                            .foregroundStyle(Color.inkSoft)
                        }
                        if preview.replacesExisting {
                            Label(
                                "This stage already has a transcript. Confirming replaces it.",
                                systemImage: "exclamationmark.triangle"
                            )
                            .font(.callout)
                            .foregroundStyle(Color.clay)
                        }
                        ForEach(TranscriptReadoutModel.rows(for: preview.segments)) { row in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                if let time = row.timeLabel {
                                    Text(time).monospacedDigit().trailMetadata()
                                }
                                Text(row.speaker == .me ? "You" : "Them")
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(row.speaker == .me ? Color.pine : Color.inkSoft)
                                    .frame(width: 44, alignment: .leading)
                                Text(row.text)
                                    .font(.callout)
                                    .foregroundStyle(Color.ink)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .onChange(of: transcriptText) {
                preview = nil
                suggestedImportDate = nil
                linkHasNoTranscript = false
            }

            Divider()
            HStack {
                if let failureMessage {
                    Text(failureMessage)
                        .font(.callout)
                        .foregroundStyle(Color.clay)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                if preview == nil {
                    Button(isFetching ? "Fetching…" : "Preview") { derivePreview() }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.pine)
                        .disabled(
                            isFetching
                                || transcriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } else {
                    Button("Attach Transcript") { confirm() }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.pine)
                }
            }
            .padding(12)
            .background(Color.paperRaised)
        }
        .frame(minWidth: 460, minHeight: 480)
    }

    private func derivePreview() {
        failureMessage = nil
        // The URL door ([TRANSCRIPT-21]): a lone share link fetches instead
        // of parsing.
        if let url = GranolaSharePayload.shareLink(in: transcriptText) {
            fetchShareImport(from: url)
            return
        }
        do {
            preview = try store.preview(of: transcriptText, for: stage)
        } catch {
            failureMessage = "No speaker labels found — paste the transcript, not the notes."
        }
    }

    private func fetchShareImport(from url: URL) {
        isFetching = true
        Task {
            defer { isFetching = false }
            do {
                let imported = try await store.fetchShareImport(from: url, for: stage)
                if notesOverview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    notesOverview = imported.notesOverview
                }
                suggestedImportDate = imported.suggestedImportDate
                linkHasNoTranscript = !imported.hasTranscript
                preview = imported.preview
            } catch GranolaShareError.noSharedDocument {
                failureMessage = "That link doesn't look like a Granola share page."
            } catch {
                failureMessage = "Fetching the share link failed — check the connection and try again."
            }
        }
    }

    private func confirm() {
        guard let preview else { return }
        do {
            try store.confirm(
                preview, notesOverview: notesOverview, onto: stage,
                importedAt: suggestedImportDate ?? .now)
            dismiss()
        } catch {
            failureMessage = "Attaching the transcript failed."
        }
    }
}

#Preview {
    let container = try! ProfileStore.container(inMemory: true)
    let stage = Stage(kind: .technical)
    ModelContext(container).insert(stage)
    return TranscriptImportSheet(
        store: TranscriptImportStore(container: container),
        stage: stage,
        initialText: "Me (00:05): Thanks for making time.\nJane: Of course."
    )
}

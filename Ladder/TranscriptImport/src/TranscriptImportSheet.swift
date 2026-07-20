import SwiftData
import SwiftUI

/// Import → preview → confirm (decisions/0004). The share link is the
/// primary door ([TRANSCRIPT-21]); manual paste sits behind a disclosure,
/// each artifact in its own field. Nothing lands on the Stage until the
/// confirm; cancelling writes nothing ([TRANSCRIPT-13]).
struct TranscriptImportSheet: View {
    var store: TranscriptImportStore
    var stage: Stage
    /// Pre-filled when a file drop opened the sheet ([TRANSCRIPT-11]).
    var initialText: String = ""
    @Environment(\.dismiss) private var dismiss

    @State private var shareLinkText = ""
    @State private var transcriptText: String
    @State private var notesOverview = ""
    @State private var manualExpanded: Bool
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
        // A file drop is a manual import — land the user on their text.
        _manualExpanded = State(initialValue: !initialText.isEmpty)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Import from Granola") {
                    TextField("https://notes.granola.ai/t/…", text: $shareLinkText)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                    Text("Paste the call's share link — Preview fetches the notes and, when the link includes it, the transcript.")
                        .font(.callout)
                        .foregroundStyle(Color.inkSoft)
                }

                DisclosureGroup("Paste manually instead", isExpanded: $manualExpanded) {
                    LabeledContent("Transcript") {
                        TextEditor(text: $transcriptText)
                            .font(.callout)
                            .frame(minHeight: 100)
                    }
                    LabeledContent("Notes overview") {
                        TextEditor(text: $notesOverview)
                            .font(.callout)
                            .frame(minHeight: 60)
                    }
                }

                if let preview {
                    Section("Preview") {
                        if linkHasNoTranscript {
                            Label(
                                "Granola share pages expose the notes only — the transcript stays behind your Granola login. Open the transcript in Granola, copy it, and paste it under Paste manually.",
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
                        if !notesOverview.isEmpty {
                            Text("Notes overview")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(Color.inkSoft)
                            NotesOverviewCard(notes: notesOverview)
                        }
                        if !preview.segments.isEmpty, !notesOverview.isEmpty {
                            Text("Transcript")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(Color.inkSoft)
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
            .onChange(of: shareLinkText) { resetPreview() }
            .onChange(of: transcriptText) { resetPreview() }

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
                        .disabled(isFetching || !hasInput)
                } else {
                    Button("Attach Transcript") { confirm() }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.pine)
                }
            }
            .padding(12)
            .background(Color.paperRaised)
        }
        .frame(minWidth: 480, minHeight: 460)
    }

    private var hasInput: Bool {
        !shareLinkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !transcriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func resetPreview() {
        preview = nil
        suggestedImportDate = nil
        linkHasNoTranscript = false
        failureMessage = nil
    }

    private func derivePreview() {
        failureMessage = nil
        let link = shareLinkText.trimmingCharacters(in: .whitespacesAndNewlines)
        // The primary door ([TRANSCRIPT-21]): the link field wins when filled.
        if !link.isEmpty {
            guard let url = GranolaSharePayload.shareLink(in: link) else {
                failureMessage = "That's not a Granola share link — it looks like notes.granola.ai/t/…"
                return
            }
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
        stage: stage
    )
}

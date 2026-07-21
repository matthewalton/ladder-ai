import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ApplicationDetailView: View {
    private static let docxType = UTType(filenameExtension: "docx") ?? .data

    @Bindable var store: PipelineStore
    var application: Application
    /// Injected as a closure so this slice never depends on a calendar-sync
    /// type; nil renders no button.
    var onLookBack: (() -> Void)?

    @State private var source: String
    @State private var notes: String
    @State private var jobDescription: String
    @State private var stageBeingEdited: Stage?
    @State private var isAddingStage = false
    @State private var saveFailed = false
    @State private var isPickingJDFile = false
    @State private var isEnteringJDLink = false
    @State private var jdLinkText = ""
    @State private var pendingJDImport: JDImportSource?
    @State private var jdImportFailureMessage: String?
    // The collapse decision is made at appearance ([PIPEBOARD-29/30]) —
    // these never flip mid-typing, only on remove.
    @State private var showsNotesIndicator: Bool
    @State private var showsJDIndicator: Bool
    @State private var pendingRemoval: LongTextRemoval?
    @Environment(\.openWindow) private var openWindow

    enum JDImportSource: Equatable {
        case file(URL)
        case link(URL)
    }

    enum LongTextRemoval: String, Identifiable {
        case notes, jobDescription
        var id: String { rawValue }
    }

    init(
        store: PipelineStore, application: Application,
        onLookBack: (() -> Void)? = nil
    ) {
        self.store = store
        self.application = application
        self.onLookBack = onLookBack
        _source = State(initialValue: application.source ?? "")
        _notes = State(initialValue: application.notes)
        _jobDescription = State(initialValue: application.jobDescription)
        _showsNotesIndicator = State(
            initialValue: LongTextField.collapsesAtAppearance(application.notes))
        _showsJDIndicator = State(
            initialValue: LongTextField.collapsesAtAppearance(application.jobDescription))
    }

    var body: some View {
        Form {
            Section {
                Text(application.company)
                    .font(.title3.bold())
                    .foregroundStyle(Color.ink)
                Text(application.roleTitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSoft)
                Text(application.status.columnTitle)
                    .font(.caption)
                    .foregroundStyle(application.status.chipForeground)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        application.status.chipBackground,
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .listRowBackground(Color.paperRaised)

            Section("Details") {
                TextField("Source — referral, LinkedIn, direct…", text: $source)
                    .onSubmit(saveDetails)
                if let appliedAt = application.appliedAt {
                    LabeledContent("Applied") {
                        Text(appliedAt, style: .date)
                            .monospacedDigit()
                            .foregroundStyle(Color.inkSoft)
                    }
                }
                if let onLookBack {
                    Button {
                        onLookBack()
                    } label: {
                        Label(
                            "Check calendar history",
                            systemImage: "clock.arrow.circlepath"
                        )
                    }
                    .buttonStyle(.borderless)
                }
            }
            .listRowBackground(Color.paperRaised)

            Section("Notes") {
                if showsNotesIndicator {
                    IndicatorRow(
                        label: "Notes set",
                        icon: "note.text",
                        onOpen: {
                            openWindow(
                                id: NotesEditWindow.windowID,
                                value: application.persistentModelID)
                        },
                        onRemove: { pendingRemoval = .notes }
                    )
                } else {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                        .scrollContentBackground(.hidden)
                        .onChange(of: notes) { saveDetails() }
                }
            }
            .listRowBackground(Color.paperRaised)

            Section {
                if showsJDIndicator {
                    IndicatorRow(
                        label: "Job description set",
                        icon: "doc.text",
                        onOpen: {
                            openWindow(
                                id: JobDescriptionWindow.windowID,
                                value: application.persistentModelID)
                        },
                        onRemove: { pendingRemoval = .jobDescription }
                    )
                } else {
                    TextEditor(text: $jobDescription)
                        .frame(minHeight: 60)
                        .scrollContentBackground(.hidden)
                        .onChange(of: jobDescription) { saveDetails() }
                }
                if let jdImportFailureMessage {
                    Text(jdImportFailureMessage)
                        .font(.callout)
                        .foregroundStyle(Color.clay)
                }
            } header: {
                HStack {
                    Text("Job Description")
                    Spacer()
                    Menu {
                        Button("From File…") { isPickingJDFile = true }
                        Button("From Link…") {
                            jdLinkText = ""
                            isEnteringJDLink = true
                        }
                    } label: {
                        Label("Import job description", systemImage: "arrow.down.doc")
                            .labelStyle(.iconOnly)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("Import a job description from a PDF/docx file or a link")
                }
            }
            .listRowBackground(Color.paperRaised)

            Section {
                ForEach(application.orderedStages) { stage in
                    Button {
                        stageBeingEdited = stage
                    } label: {
                        HStack(spacing: 8) {
                            BlazeMark(
                                blaze: TimelineModel.blaze(for: stage.kind),
                                filled: stage.outcome != .pending,
                                size: 10,
                                tint: stage.kind.accent
                            )
                            Text(stage.kind.label)
                                .foregroundStyle(Color.ink)
                            Spacer()
                            Text(stage.outcome.label)
                                .font(.caption)
                                .foregroundStyle(
                                    stage.outcome == .passed ? Color.summitGold : Color.inkSoft)
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Delete Stage", role: .destructive) {
                            try? store.deleteStage(stage)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Stages")
                    Spacer()
                    Button {
                        isAddingStage = true
                    } label: {
                        Label("Add Stage", systemImage: "plus")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listRowBackground(Color.paperRaised)

            // Renders only at offer or once a narrative exists — the
            // journey-synthesis slice owns the section ([JOURNEY-14/15]).
            JourneySection(container: store.container, application: application)

            if saveFailed {
                Text("Saving the application failed.")
                    .font(.callout)
                    .foregroundStyle(Color.clay)
                    .listRowBackground(Color.paperRaised)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.paper)
        .sheet(isPresented: $isAddingStage) {
            StageFormView(store: store, application: application)
        }
        .sheet(item: $stageBeingEdited) { stage in
            StageFormView(store: store, application: application, stage: stage)
        }
        .fileImporter(
            isPresented: $isPickingJDFile,
            allowedContentTypes: [.pdf, Self.docxType]
        ) { result in
            guard case .success(let url) = result else { return }
            requestJDImport(.file(url))
        }
        .alert("Import from Link", isPresented: $isEnteringJDLink) {
            TextField("https://…", text: $jdLinkText)
            Button("Import") { submitJDLink() }
            Button("Cancel", role: .cancel) { jdLinkText = "" }
        } message: {
            Text("The page's text will be imported as the job description.")
        }
        .confirmationDialog(
            "Replace the existing job description?",
            isPresented: Binding(
                get: { pendingJDImport != nil },
                set: { if !$0 { pendingJDImport = nil } }
            ),
            presenting: pendingJDImport
        ) { source in
            Button("Replace", role: .destructive) {
                pendingJDImport = nil
                performJDImport(source)
            }
            Button("Cancel", role: .cancel) {
                pendingJDImport = nil
            }
        } message: { _ in
            Text("The imported text will replace the current job description.")
        }
        .confirmationDialog(
            pendingRemoval == .notes
                ? "Remove the notes?" : "Remove the job description?",
            isPresented: Binding(
                get: { pendingRemoval != nil },
                set: { if !$0 { pendingRemoval = nil } }
            ),
            presenting: pendingRemoval
        ) { removal in
            Button("Remove", role: .destructive) {
                pendingRemoval = nil
                performRemoval(removal)
            }
            Button("Cancel", role: .cancel) {
                pendingRemoval = nil
            }
        } message: { removal in
            Text(
                removal == .notes
                    ? "The notes will be cleared."
                    : "The job description will be cleared.")
        }
    }

    /// The confirmed remove ([PIPEBOARD-33]): clear through the store, then
    /// hand the field back to its inline editor ([PIPEBOARD-30]).
    private func performRemoval(_ removal: LongTextRemoval) {
        do {
            switch removal {
            case .notes:
                try store.clearNotes(of: application)
                notes = ""
                showsNotesIndicator = false
            case .jobDescription:
                try store.clearJobDescription(of: application)
                jobDescription = ""
                showsJDIndicator = false
            }
        } catch {
            saveFailed = true
        }
    }

    /// Empty (or whitespace-only) job descriptions have nothing worth
    /// protecting — the import lands without a confirmation step
    /// ([PIPEBOARD-25]).
    static func jdImportNeedsConfirmation(existing: String) -> Bool {
        !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submitJDLink() {
        let trimmed = jdLinkText.trimmingCharacters(in: .whitespacesAndNewlines)
        jdLinkText = ""
        guard let url = URL(string: trimmed), url.scheme?.hasPrefix("http") == true else {
            jdImportFailureMessage = "That link isn't a valid URL."
            return
        }
        requestJDImport(.link(url))
    }

    private func requestJDImport(_ source: JDImportSource) {
        if Self.jdImportNeedsConfirmation(existing: application.jobDescription) {
            pendingJDImport = source
        } else {
            performJDImport(source)
        }
    }

    private func performJDImport(_ source: JDImportSource) {
        switch source {
        case .file(let url):
            importJobDescription(fromFile: url)
        case .link(let url):
            Task { await importJobDescription(fromLink: url) }
        }
    }

    private func importJobDescription(fromFile url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        do {
            try store.importJobDescription(from: url, into: application)
            jobDescription = application.jobDescription
            jdImportFailureMessage = nil
        } catch TextExtractionError.unsupportedFileType {
            jdImportFailureMessage = "Only PDF and docx files can be imported."
        } catch {
            jdImportFailureMessage = "No text could be extracted from that file."
        }
    }

    private func importJobDescription(fromLink url: URL) async {
        do {
            try await store.importJobDescription(fromLink: url, into: application)
            jobDescription = application.jobDescription
            jdImportFailureMessage = nil
        } catch TextExtractionError.noExtractableText {
            jdImportFailureMessage = "No text could be extracted from that page."
        } catch {
            jdImportFailureMessage = "The link couldn't be fetched."
        }
    }

    private func saveDetails() {
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            // A collapsed field's inline state is stale by definition — its
            // window may have edited the model — so pass the live value.
            try store.updateDetails(
                application,
                source: trimmedSource.isEmpty ? nil : trimmedSource,
                notes: showsNotesIndicator ? application.notes : notes,
                appliedAt: application.appliedAt,
                jobDescription: showsJDIndicator ? application.jobDescription : jobDescription
            )
        } catch {
            saveFailed = true
        }
    }
}

#Preview {
    let store = try! PipelineStore(container: ProfileStore.container(inMemory: true))
    let application = Application(
        company: "Summit Labs", roleTitle: "Platform Engineer",
        jobDescription: "Own platform reliability.", status: .active,
        appliedAt: .now.addingTimeInterval(-12 * 86_400)
    )
    return ApplicationDetailView(store: store, application: application)
        .frame(width: 320, height: 560)
}

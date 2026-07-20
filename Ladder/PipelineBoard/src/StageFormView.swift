import SwiftUI

struct StageFormView: View {
    @Bindable var store: PipelineStore
    var application: Application
    var stage: Stage?
    @Environment(\.dismiss) private var dismiss

    @State private var knownKind: StageKind = .screen
    @State private var isOther = false
    @State private var otherLabel = ""
    @State private var hasSchedule = false
    @State private var scheduledAt = Date.now
    @State private var outcome: StageOutcome = .pending
    @State private var hasHeardBack = false
    @State private var heardBackAt = Date.now
    @State private var prepContext = ""
    @State private var meetingURLText = ""
    @State private var saveFailed = false
    // The collapse decision is made at appearance ([PIPEBOARD-29/30]) — it
    // never flips mid-typing, only on remove. A new Stage always edits
    // inline: it has no prep context yet.
    @State private var showsPrepContextIndicator = false
    @State private var isConfirmingPrepContextRemoval = false
    @Environment(\.openWindow) private var openWindow

    init(store: PipelineStore, application: Application, stage: Stage? = nil) {
        self.store = store
        self.application = application
        self.stage = stage
        guard let stage else { return }
        _showsPrepContextIndicator = State(
            initialValue: LongTextField.collapsesAtAppearance(stage.prepContext))
        if case .other(let label) = stage.kind {
            _isOther = State(initialValue: true)
            _otherLabel = State(initialValue: label)
        } else {
            _knownKind = State(initialValue: stage.kind)
        }
        if let date = stage.scheduledAt {
            _hasSchedule = State(initialValue: true)
            _scheduledAt = State(initialValue: date)
        }
        _outcome = State(initialValue: stage.outcome)
        if let date = stage.heardBackAt {
            _hasHeardBack = State(initialValue: true)
            _heardBackAt = State(initialValue: date)
        }
        _prepContext = State(initialValue: stage.prepContext)
        _meetingURLText = State(initialValue: stage.meetingURL?.absoluteString ?? "")
    }

    private var chosenKind: StageKind {
        isOther ? .other(otherLabel.trimmingCharacters(in: .whitespacesAndNewlines)) : knownKind
    }

    private var canSave: Bool {
        !isOther || !otherLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Picker("Kind", selection: $knownKind) {
                    ForEach(StageKind.knownCases, id: \.self) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .disabled(isOther)
                Toggle("Other", isOn: $isOther)
                if isOther {
                    TextField("What kind of stage?", text: $otherLabel)
                }

                Toggle("Scheduled", isOn: $hasSchedule)
                if hasSchedule {
                    DatePicker("When", selection: $scheduledAt)
                }

                Picker("Outcome", selection: $outcome) {
                    ForEach(StageOutcome.allCases, id: \.self) { outcome in
                        Text(outcome.label).tag(outcome)
                    }
                }
                Toggle("Heard back", isOn: $hasHeardBack)
                if hasHeardBack {
                    DatePicker("On", selection: $heardBackAt)
                }

                TextField("Meeting link", text: $meetingURLText)
                Section("Prep context") {
                    if let stage, showsPrepContextIndicator {
                        IndicatorRow(
                            label: "Prep context set",
                            icon: "text.alignleft",
                            onOpen: {
                                openWindow(
                                    id: PrepContextEditWindow.windowID,
                                    value: stage.persistentModelID)
                            },
                            onRemove: { isConfirmingPrepContextRemoval = true }
                        )
                        .confirmationDialog(
                            "Remove the prep context?",
                            isPresented: $isConfirmingPrepContextRemoval
                        ) {
                            Button("Remove", role: .destructive) { removePrepContext() }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("The prep context will be cleared.")
                        }
                    } else {
                        TextEditor(text: $prepContext)
                            .frame(minHeight: 80)
                    }
                }

                // Granola notes attach directly from the Stage form
                // (TranscriptImport decisions/0007). Only a persisted Stage
                // can carry them — and only then is there anything to
                // debrief (Ladder/Debrief/).
                if let stage {
                    GranolaNotesSection(container: store.container, stage: stage)
                    DebriefSection(container: store.container, stage: stage)
                    PrepPackSection(container: store.container, stage: stage)
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                if saveFailed {
                    Text("Saving the stage failed.")
                        .font(.callout)
                        .foregroundStyle(Color.clay)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                Button(stage == nil ? "Add Stage" : "Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.pine)
                    .disabled(!canSave)
            }
            .padding(12)
            .background(Color.paperRaised)
        }
        .frame(minWidth: 420, minHeight: 440)
    }

    /// The confirmed remove ([PIPEBOARD-33]): clear through the store, then
    /// hand the field back to its inline editor ([PIPEBOARD-30]).
    private func removePrepContext() {
        guard let stage else { return }
        do {
            try store.clearPrepContext(of: stage)
            prepContext = ""
            showsPrepContextIndicator = false
        } catch {
            saveFailed = true
        }
    }

    private func save() {
        let meetingURL = meetingURLText.isEmpty ? nil : URL(string: meetingURLText)
        // A collapsed prep context's inline state is stale by definition —
        // its window may have edited the model — so save the live value.
        let prepContextToSave =
            showsPrepContextIndicator ? (stage?.prepContext ?? prepContext) : prepContext
        do {
            if let stage {
                try store.updateStage(
                    stage,
                    kind: chosenKind,
                    scheduledAt: hasSchedule ? scheduledAt : nil,
                    outcome: outcome,
                    heardBackAt: hasHeardBack ? heardBackAt : nil,
                    prepContext: prepContextToSave,
                    meetingURL: meetingURL
                )
            } else {
                let created = try store.addStage(
                    to: application,
                    kind: chosenKind,
                    scheduledAt: hasSchedule ? scheduledAt : nil,
                    meetingURL: meetingURL,
                    prepContext: prepContext
                )
                if outcome != .pending || hasHeardBack {
                    try store.updateStage(
                        created,
                        kind: chosenKind,
                        scheduledAt: hasSchedule ? scheduledAt : nil,
                        outcome: outcome,
                        heardBackAt: hasHeardBack ? heardBackAt : nil,
                        prepContext: prepContext,
                        meetingURL: meetingURL
                    )
                }
            }
            dismiss()
        } catch {
            saveFailed = true
        }
    }
}

#Preview {
    let store = try! PipelineStore(container: ProfileStore.container(inMemory: true))
    let application = Application(
        company: "Summit Labs", roleTitle: "Platform Engineer",
        jobDescription: "Own platform reliability.", status: .active
    )
    return StageFormView(store: store, application: application)
}

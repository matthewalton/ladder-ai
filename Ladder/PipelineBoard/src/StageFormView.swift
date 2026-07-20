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

    init(store: PipelineStore, application: Application, stage: Stage? = nil) {
        self.store = store
        self.application = application
        self.stage = stage
        guard let stage else { return }
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
                    TextEditor(text: $prepContext)
                        .frame(minHeight: 80)
                }

                // Import entry + readout live on the Stage form — the app's
                // Stage detail surface (TranscriptImport decisions/0004).
                // Only a persisted Stage can carry a transcript.
                if let stage {
                    TranscriptSectionView(container: store.container, stage: stage)
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

    private func save() {
        let meetingURL = meetingURLText.isEmpty ? nil : URL(string: meetingURLText)
        do {
            if let stage {
                try store.updateStage(
                    stage,
                    kind: chosenKind,
                    scheduledAt: hasSchedule ? scheduledAt : nil,
                    outcome: outcome,
                    heardBackAt: hasHeardBack ? heardBackAt : nil,
                    prepContext: prepContext,
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

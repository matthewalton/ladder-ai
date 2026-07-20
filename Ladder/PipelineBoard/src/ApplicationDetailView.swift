import SwiftData
import SwiftUI

struct ApplicationDetailView: View {
    @Bindable var store: PipelineStore
    var application: Application
    /// Injected as a closure so this slice never depends on a calendar-sync
    /// type; nil renders no button.
    var onLookBack: (() -> Void)?

    @State private var source: String
    @State private var notes: String
    @State private var stageBeingEdited: Stage?
    @State private var isAddingStage = false
    @State private var saveFailed = false

    init(
        store: PipelineStore, application: Application,
        onLookBack: (() -> Void)? = nil
    ) {
        self.store = store
        self.application = application
        self.onLookBack = onLookBack
        _source = State(initialValue: application.source ?? "")
        _notes = State(initialValue: application.notes)
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
                TextEditor(text: $notes)
                    .frame(minHeight: 60)
                    .scrollContentBackground(.hidden)
                    .onChange(of: notes) { saveDetails() }
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
    }

    private func saveDetails() {
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try store.updateDetails(
                application,
                source: trimmedSource.isEmpty ? nil : trimmedSource,
                notes: notes,
                appliedAt: application.appliedAt
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

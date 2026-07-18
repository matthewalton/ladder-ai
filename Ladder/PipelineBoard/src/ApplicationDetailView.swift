import SwiftData
import SwiftUI

/// The application detail (inspector content): source, applied date, notes,
/// and the Stage chain with add/edit/delete ([PIPEBOARD-12], Stage CRUD).
struct ApplicationDetailView: View {
    @Bindable var store: PipelineStore
    var application: Application

    @State private var source: String
    @State private var notes: String
    @State private var stageBeingEdited: Stage?
    @State private var isAddingStage = false
    @State private var saveFailed = false

    init(store: PipelineStore, application: Application) {
        self.store = store
        self.application = application
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
                    .foregroundStyle(Color.pine)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.pineTint, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            Section("Details") {
                TextField("Source — referral, LinkedIn, direct…", text: $source)
                    .onSubmit(saveDetails)
                if let appliedAt = application.appliedAt {
                    LabeledContent("Applied") {
                        Text(appliedAt, style: .date)
                            .foregroundStyle(Color.inkSoft)
                    }
                }
            }

            Section("Notes") {
                TextEditor(text: $notes)
                    .frame(minHeight: 60)
                    .onChange(of: notes) { saveDetails() }
            }

            Section {
                ForEach(application.orderedStages) { stage in
                    Button {
                        stageBeingEdited = stage
                    } label: {
                        HStack {
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

            if saveFailed {
                Text("Saving the application failed.")
                    .font(.callout)
                    .foregroundStyle(Color.clay)
            }
        }
        .formStyle(.grouped)
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

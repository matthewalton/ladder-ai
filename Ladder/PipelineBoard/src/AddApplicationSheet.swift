import SwiftData
import SwiftUI

/// The manual add form (decisions/0004, [PIPEBOARD-20]): company and role
/// title required, Draft-or-Applied choice with an "Applied on" date when
/// applied ([PIPEBOARD-17]/[PIPEBOARD-18]), optional source and notes. The
/// store's blank-field throw is the guarantee; the disabled Add button just
/// mirrors it ([PIPEBOARD-19]).
struct AddApplicationSheet: View {
    enum InitialStatus: String, CaseIterable {
        case draft = "Draft"
        case applied = "Applied"
    }

    @Bindable var store: PipelineStore

    @Environment(\.dismiss) private var dismiss
    @State private var company = ""
    @State private var roleTitle = ""
    @State private var status: InitialStatus = .applied
    @State private var appliedAt = Date.now
    @State private var source = ""
    @State private var notes = ""
    @State private var saveFailed = false

    private var canAdd: Bool {
        !company.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !roleTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add application")
                .font(.trailNarrative(.title3))
                .foregroundStyle(Color.ink)

            Form {
                TextField("Company", text: $company)
                TextField("Role title", text: $roleTitle)
                Picker("Status", selection: $status) {
                    ForEach(InitialStatus.allCases, id: \.self) { choice in
                        Text(choice.rawValue).tag(choice)
                    }
                }
                .pickerStyle(.segmented)
                if status == .applied {
                    DatePicker("Applied on", selection: $appliedAt, displayedComponents: .date)
                }
                TextField("Source", text: $source, prompt: Text("Referral, job board…"))
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
            .formStyle(.columns)

            if saveFailed {
                Text("Saving failed. Nothing was added — try again.")
                    .font(.callout)
                    .foregroundStyle(Color.clay)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Add") { add() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canAdd)
            }
        }
        .padding(20)
        .frame(minWidth: 380)
        .background(Color.paper)
    }

    private func add() {
        do {
            try store.createApplication(
                company: company,
                roleTitle: roleTitle,
                source: source.isEmpty ? nil : source,
                notes: notes,
                appliedAt: status == .applied ? appliedAt : nil
            )
            dismiss()
        } catch {
            saveFailed = true
        }
    }
}

#Preview {
    let store = try! PipelineStore(container: ProfileStore.container(inMemory: true))
    return AddApplicationSheet(store: store)
}

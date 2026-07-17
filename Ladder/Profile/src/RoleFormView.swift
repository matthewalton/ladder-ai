import SwiftUI

/// Sheet for adding a role. Used by the add-first-role empty state and the
/// editor sidebar.
struct RoleFormView: View {
    @Bindable var store: ProfileStore
    @Environment(\.dismiss) private var dismiss

    @State private var company = ""
    @State private var title = ""
    @State private var start = Date.now
    @State private var isCurrent = true
    @State private var end = Date.now

    private var isValid: Bool {
        !company.trimmingCharacters(in: .whitespaces).isEmpty
            && !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Form {
            TextField("Company", text: $company)
            TextField("Title", text: $title)
            DatePicker("Started", selection: $start, displayedComponents: .date)
            Toggle("Current role", isOn: $isCurrent)
            if !isCurrent {
                DatePicker("Ended", selection: $end, displayedComponents: .date)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 360)
        .padding()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add role") {
                    try? store.addRole(
                        company: company.trimmingCharacters(in: .whitespaces),
                        title: title.trimmingCharacters(in: .whitespaces),
                        start: start,
                        end: isCurrent ? nil : end
                    )
                    dismiss()
                }
                .disabled(!isValid)
            }
        }
    }
}

#Preview {
    let store = try! ProfileStore(container: ProfileStore.container(inMemory: true))
    try! store.createProfile(name: "Alex Climber", headline: "Staff Engineer")
    return RoleFormView(store: store)
}

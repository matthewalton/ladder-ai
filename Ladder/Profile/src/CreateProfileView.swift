import SwiftUI

/// The only place a Profile can be created.
struct CreateProfileView: View {
    @Bindable var store: ProfileStore

    @State private var name = ""
    @State private var headline = ""
    @State private var creationFailed = false

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Every climb starts with you.")
                .font(.trailNarrative(.title2))
                .foregroundStyle(Color.inkSoft)

            VStack(spacing: 12) {
                TextField("Your name", text: $name)
                    .textFieldStyle(.roundedBorder)
                TextField("Headline — e.g. Senior iOS Engineer", text: $headline)
                    .textFieldStyle(.roundedBorder)
            }
            .frame(maxWidth: 360)

            Button("Create profile") {
                do {
                    try store.createProfile(name: name, headline: headline)
                } catch {
                    creationFailed = true
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.pine)
            .disabled(trimmedName.isEmpty)

            if creationFailed {
                Text("A profile already exists. Relaunch the app.")
                    .font(.callout)
                    .foregroundStyle(Color.clay)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ContourBackground()
                .background(Color.paper)
        }
    }
}

#Preview {
    let store = try! ProfileStore(container: ProfileStore.container(inMemory: true))
    return CreateProfileView(store: store)
}

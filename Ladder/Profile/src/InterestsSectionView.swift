import SwiftUI

/// INTERESTS — a light chip row; the one section with no depth to edit.
struct InterestsSectionView: View {
    @Bindable var store: ProfileStore
    let profile: Profile

    @State private var newInterest = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProfileSectionHeader(title: "Interests")

            if !profile.interests.isEmpty {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 90), alignment: .leading)],
                    alignment: .leading, spacing: 4
                ) {
                    ForEach(Array(profile.interests.enumerated()), id: \.element) { index, interest in
                        Text(interest)
                            .font(.caption)
                            .foregroundStyle(Color.ink)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.pineTint, in: RoundedRectangle(cornerRadius: 6))
                            .contextMenu {
                                Button("Remove", role: .destructive) {
                                    try? store.removeInterest(at: index)
                                }
                            }
                    }
                }
            }

            HStack {
                TextField("Add an interest", text: $newInterest)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .foregroundStyle(Color.inkSoft)
                    .onSubmit(addInterest)
                if !newInterest.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button("Add", action: addInterest)
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
            }
        }
    }

    private func addInterest() {
        try? store.addInterest(newInterest)
        newInterest = ""
    }
}

#Preview {
    let store = try! ProfileStore(container: ProfileStore.container(inMemory: true))
    let profile = try! store.createProfile(name: "Alex Climber", headline: "Staff Engineer")
    try! store.addInterest("climbing")
    try! store.addInterest("trail running")
    return InterestsSectionView(store: store, profile: profile)
        .padding()
        .background(Color.paper)
        .frame(width: 640)
}

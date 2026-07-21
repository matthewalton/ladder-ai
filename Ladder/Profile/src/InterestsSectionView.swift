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
                        InterestChipView(name: interest) {
                            try? store.removeInterest(at: index)
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

/// One interest chip; hovering reveals its remove control.
private struct InterestChipView: View {
    let name: String
    let onRemove: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 4) {
            Text(name)
                .font(.caption)
                .foregroundStyle(Color.ink)
            if isHovering {
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundStyle(Color.clay)
                }
                .buttonStyle(.borderless)
                .help("Remove interest")
                .accessibilityLabel("Remove \(name)")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.pineTint, in: RoundedRectangle(cornerRadius: 6))
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Remove", role: .destructive, action: onRemove)
        }
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

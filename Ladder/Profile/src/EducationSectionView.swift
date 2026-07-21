import SwiftUI

/// EDUCATION — entries newest-first; fields are edited in the detail rail.
struct EducationSectionView: View {
    @Bindable var store: ProfileStore
    let profile: Profile
    @Binding var focus: ProfileFocus?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ProfileSectionHeader(title: "Education")
                Spacer()
                Button("Add education", systemImage: "plus", action: addEducation)
                    .buttonStyle(.borderless)
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
            }

            if profile.education.isEmpty {
                Text("Where did you learn the ropes?")
                    .font(.trailNarrative(.body))
                    .foregroundStyle(Color.inkSoft)
            } else {
                ForEach(profile.orderedEducation, id: \.persistentModelID) { education in
                    row(education)
                }
            }
        }
    }

    private func row(_ education: Education) -> some View {
        let isFocused = focus == .education(education)
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                Text(education.institution.isEmpty ? "New institution" : education.institution)
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                if !education.qualification.isEmpty {
                    Text(education.qualification)
                        .font(.caption)
                        .foregroundStyle(Color.inkSoft)
                }
                if !education.detail.isEmpty {
                    Text(education.detail)
                        .font(.caption)
                        .foregroundStyle(Color.inkSoft)
                }
            }
            Spacer()
            Text(profileDateRange(start: education.start, end: education.end))
                .trailMetadata()
                .foregroundStyle(Color.inkSoft)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            isFocused ? Color.paperRaised : Color.clear,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isFocused ? Color.pine : Color.clear, lineWidth: 2))
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture { focus = .education(education) }
        .contextMenu {
            Button("Delete education", role: .destructive) { delete(education) }
        }
    }

    private func addEducation() {
        guard
            let education = try? store.addEducation(
                institution: "", qualification: "", start: .now, end: nil)
        else { return }
        focus = .education(education)
    }

    private func delete(_ education: Education) {
        if focus == .education(education) { focus = nil }
        try? store.deleteEducation(education)
    }
}

#Preview {
    let store = try! ProfileStore(container: ProfileStore.container(inMemory: true))
    let profile = try! store.createProfile(name: "Alex Climber", headline: "Staff Engineer")
    try! store.addEducation(
        institution: "University of Example", qualification: "BSc Computer Science",
        start: Date(timeIntervalSince1970: 1_100_000_000),
        end: Date(timeIntervalSince1970: 1_200_000_000),
        detail: "First-class honours"
    )
    return EducationSectionView(store: store, profile: profile, focus: .constant(nil))
        .padding()
        .background(Color.paper)
        .frame(width: 640)
}

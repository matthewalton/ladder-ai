import SwiftUI

enum ProfileFocus: Hashable {
    case role(Role)
    case point(Achievement)
    case education(Education)
    case project(Project)
}

struct ProfilePageView: View {
    @Bindable var store: ProfileStore

    @State private var focus: ProfileFocus?
    @State private var isImportingCV = false

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                if let profile = store.profile {
                    VStack(alignment: .leading, spacing: 32) {
                        ProfileHeaderView(store: store, profile: profile)
                        ExperienceSectionView(store: store, profile: profile, focus: $focus)
                        EducationSectionView(store: store, profile: profile, focus: $focus)
                        ProjectsSectionView(store: store, profile: profile, focus: $focus)
                        InterestsSectionView(store: store, profile: profile)
                    }
                    .frame(maxWidth: 720, alignment: .leading)
                    .padding(28)
                    .frame(maxWidth: .infinity)
                }
            }
            .background(Color.paper)
            // Row taps win over this page-level tap — the deeper gesture
            // takes precedence.
            .contentShape(Rectangle())
            .onTapGesture { focus = nil }
            .onExitCommand { focus = nil }

            Divider()

            ProfileDetailRail(store: store, focus: $focus)
                .frame(width: 300)
                .background(Color.paper)
        }
        .navigationTitle("Profile")
        .toolbar {
            ToolbarItem {
                Button("Import CV", systemImage: "arrow.down.document") {
                    isImportingCV = true
                }
            }
        }
        .sheet(isPresented: $isImportingCV) {
            ImportCVView(profileStore: store)
        }
    }
}

struct ProfileSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .kerning(1.4)
            .textCase(.uppercase)
            .foregroundStyle(Color.inkSoft)
    }
}

struct PageAddField: View {
    let prompt: String
    @Binding var text: String
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus")
                .font(.caption)
                .foregroundStyle(Color.inkSoft)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(.callout)
                .foregroundStyle(Color.ink)
                .onSubmit(onSubmit)
            if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                Button("Add", action: onSubmit)
                    .buttonStyle(.borderless)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.paperRaised.opacity(0.6), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.mist, lineWidth: 1))
    }
}

func profileDateRange(start: Date, end: Date?) -> String {
    let style = Date.FormatStyle().month(.abbreviated).year()
    return "\(start.formatted(style)) – \(end?.formatted(style) ?? "Present")"
}

#Preview {
    let store = try! ProfileStore(container: ProfileStore.container(inMemory: true))
    try! store.createProfile(name: "Alex Climber", headline: "Staff Engineer")
    let role = try! store.addRole(company: "Acme", title: "Senior Engineer", start: .now, end: nil)
    let point = try! store.addAchievement(to: role, text: "Won the first internal AI Olympiad")
    try! store.tag(point, skillNamed: "AI Engineering")
    try! store.addEducation(
        institution: "University of Example", qualification: "BSc Computer Science",
        start: Date(timeIntervalSince1970: 1_100_000_000),
        end: Date(timeIntervalSince1970: 1_200_000_000)
    )
    let project = try! store.addProject(
        name: "Trail Mapper", link: "https://example.com", summary: "Offline-first hiking maps",
        details: "Built tile caching so a week's maps survive without signal."
    )
    try! store.tag(project, skillNamed: "Swift")
    try! store.addInterest("climbing")
    return ProfilePageView(store: store)
        .frame(width: 1100, height: 700)
}

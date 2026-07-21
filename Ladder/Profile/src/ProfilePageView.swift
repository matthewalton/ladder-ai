import SwiftUI

/// What the detail rail is editing. Focus is transient view state — the
/// sections set it, the rail renders it.
enum ProfileFocus: Hashable {
    case role(Role)
    case point(Achievement)
    case education(Education)
    case project(Project)
}

/// The Profile editor: a single scrollable CV-style page beside a slim,
/// persistent detail rail.
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
            // Tailoring lives in the Applications section (PipelineBoard
            // decisions/0007) — the Profile is curated here, trimmed there.
        }
        .sheet(isPresented: $isImportingCV) {
            ImportCVView(profileStore: store)
        }
    }
}

/// The CV-style section label shared by every page section.
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

/// Month-resolution range for roles and education rows.
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
        name: "Trail Mapper", link: "https://example.com", summary: "Offline-first hiking maps"
    )
    try! store.addPoint(to: project, text: "Built tile caching for offline use")
    try! store.addInterest("climbing")
    return ProfilePageView(store: store)
        .frame(width: 1100, height: 700)
}

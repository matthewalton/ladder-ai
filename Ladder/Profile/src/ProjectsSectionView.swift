import SwiftUI

/// PROJECTS — each project is told as one description with Tags for JD
/// matching (decisions/0009), not a bullet list.
struct ProjectsSectionView: View {
    @Bindable var store: ProfileStore
    let profile: Profile
    @Binding var focus: ProfileFocus?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ProfileSectionHeader(title: "Projects")
                Spacer()
                Button("Add project", systemImage: "plus", action: addProject)
                    .buttonStyle(.borderless)
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
            }

            if profile.projects.isEmpty {
                Text("Side quests count. Add what you've built.")
                    .font(.trailNarrative(.body))
                    .foregroundStyle(Color.inkSoft)
            } else {
                ForEach(profile.orderedProjects, id: \.persistentModelID) { project in
                    ProjectItemView(store: store, project: project, focus: $focus)
                }
            }
        }
    }

    private func addProject() {
        guard let project = try? store.addProject(name: "") else { return }
        focus = .project(project)
    }
}

private struct ProjectItemView: View {
    @Bindable var store: ProfileStore
    let project: Project
    @Binding var focus: ProfileFocus?

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            if project.details.isEmpty {
                Text("Add a description — how you'd tell this project on a CV.")
                    .font(.callout)
                    .foregroundStyle(Color.inkSoft)
                    .padding(.leading, 4)
            } else {
                Text(project.details)
                    .font(.callout)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 4)
            }
            if !project.skills.isEmpty {
                TagChipsView(names: project.skills.map(\.name).sorted())
                    .padding(.leading, 4)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { focus = .project(project) }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(project.name.isEmpty ? "New project" : project.name)
                .font(.headline)
                .foregroundStyle(Color.ink)
            if !project.link.isEmpty {
                Image(systemName: "link")
                    .font(.caption)
                    .foregroundStyle(Color.inkSoft)
            }
            if !project.summary.isEmpty {
                Text(project.summary)
                    .font(.caption)
                    .foregroundStyle(Color.inkSoft)
            }
            Spacer()
            RowDeleteButton(label: "Delete project", isVisible: isHovering, action: deleteProject)
        }
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Edit project") { focus = .project(project) }
            Button("Delete project", role: .destructive, action: deleteProject)
        }
    }

    private func deleteProject() {
        if case .project(let focused) = focus, focused == project {
            focus = nil
        }
        try? store.deleteProject(project)
    }
}

#Preview {
    let store = try! ProfileStore(container: ProfileStore.container(inMemory: true))
    let profile = try! store.createProfile(name: "Alex Climber", headline: "Staff Engineer")
    let project = try! store.addProject(
        name: "Trail Mapper", link: "https://example.com", summary: "Offline-first hiking maps",
        details: "An offline-first hiking map app with tile caching, route planning, and elevation profiles. Built to survive a week in the Cairngorms without signal."
    )
    try! store.tag(project, skillNamed: "Swift")
    try! store.tag(project, skillNamed: "MapKit")
    return ProjectsSectionView(store: store, profile: profile, focus: .constant(nil))
        .padding()
        .background(Color.paper)
        .frame(width: 640)
}

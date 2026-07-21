import SwiftUI

/// PROJECTS — each project carries its own brief points, tagged for JD
/// matching exactly like experience points.
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

    @State private var newPointText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            PointListView(
                store: store,
                points: project.orderedPoints,
                parentToken: "project-\(String(describing: project.persistentModelID))",
                focus: $focus,
                onMove: { source, destination in
                    try? store.movePoints(in: project, from: source, to: destination)
                }
            )
            .padding(.leading, 4)

            HStack {
                TextField("Add a point — a brief key talking point", text: $newPointText)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .foregroundStyle(Color.inkSoft)
                    .onSubmit(addPoint)
                if !newPointText.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button("Add", action: addPoint)
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
            }
            .padding(.leading, 20)
        }
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
        }
        .contentShape(Rectangle())
        .onTapGesture { focus = .project(project) }
        .contextMenu {
            Button("Edit project") { focus = .project(project) }
            Button("Delete project", role: .destructive, action: deleteProject)
        }
    }

    private func addPoint() {
        let text = newPointText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        try? store.addPoint(to: project, text: text)
        newPointText = ""
    }

    private func deleteProject() {
        switch focus {
        case .project(let focused) where focused == project:
            focus = nil
        case .point(let point) where point.project == project:
            focus = nil
        default:
            break
        }
        try? store.deleteProject(project)
    }
}

#Preview {
    let store = try! ProfileStore(container: ProfileStore.container(inMemory: true))
    let profile = try! store.createProfile(name: "Alex Climber", headline: "Staff Engineer")
    let project = try! store.addProject(
        name: "Trail Mapper", link: "https://example.com", summary: "Offline-first hiking maps"
    )
    let point = try! store.addPoint(to: project, text: "Built tile caching for offline use")
    try! store.tag(point, skillNamed: "Swift")
    return ProjectsSectionView(store: store, profile: profile, focus: .constant(nil))
        .padding()
        .background(Color.paper)
        .frame(width: 640)
}

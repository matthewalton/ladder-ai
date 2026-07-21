import SwiftUI

/// The slim persistent rail beside the CV page. Shows and edits the focused
/// item's depth — the STAR context that feeds the LLM but never shows on a
/// rendered CV.
struct ProfileDetailRail: View {
    @Bindable var store: ProfileStore
    @Binding var focus: ProfileFocus?

    var body: some View {
        Group {
            switch focus {
            case .point(let achievement):
                PointDetailPane(store: store, achievement: achievement)
                    .id(achievement.persistentModelID)
            case .role(let role):
                RoleDetailPane(store: store, role: role)
                    .id(role.persistentModelID)
            case .education(let education):
                EducationDetailPane(store: store, education: education)
                    .id(education.persistentModelID)
            case .project(let project):
                ProjectDetailPane(store: store, project: project)
                    .id(project.persistentModelID)
            case nil:
                placeholder
            }
        }
    }

    private var placeholder: some View {
        VStack(spacing: 12) {
            if let profile = store.profile {
                Text(profile.name)
                    .font(.trailNarrative(.title3))
                    .foregroundStyle(Color.ink)
                Text("Updated \(profile.updatedAt.formatted(date: .abbreviated, time: .omitted))")
                    .trailMetadata()
                    .foregroundStyle(Color.inkSoft)
            }
            Text("Select a point to edit its depth — tags, impact, and the story behind it.")
                .font(.callout)
                .foregroundStyle(Color.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ContourBackground()
                .background(Color.paper)
        }
    }
}

/// Depth editor for a point (role or project): wording, Tags, impact, tech,
/// strength notes.
private struct PointDetailPane: View {
    @Bindable var store: ProfileStore
    let achievement: Achievement

    @State private var text: String
    @State private var newTag = ""
    @State private var impactMetric: String
    @State private var techText: String
    @State private var strengthNotes: String

    init(store: ProfileStore, achievement: Achievement) {
        self.store = store
        self.achievement = achievement
        _text = State(initialValue: achievement.text)
        _impactMetric = State(initialValue: achievement.impactMetric ?? "")
        _techText = State(initialValue: achievement.tech.joined(separator: ", "))
        _strengthNotes = State(initialValue: achievement.strengthNotes ?? "")
    }

    private var detailsDirty: Bool {
        impactMetric != (achievement.impactMetric ?? "")
            || techText != achievement.tech.joined(separator: ", ")
            || strengthNotes != (achievement.strengthNotes ?? "")
    }

    var body: some View {
        Form {
            Section("Point") {
                TextField("A brief key talking point", text: $text, axis: .vertical)
                    .lineLimit(3...8)
                    .onSubmit(commitText)
                if text != achievement.text {
                    Button("Save wording", action: commitText)
                }
            }
            .listRowBackground(Color.paperRaised)

            Section("Tags") {
                if !achievement.skills.isEmpty {
                    TagChipsView(names: achievement.skills.map(\.name).sorted()) { name in
                        removeTag(named: name)
                    }
                }
                TextField("Add a tag", text: $newTag)
                    .onSubmit(addTag)
            }
            .listRowBackground(Color.paperRaised)

            Section("Depth") {
                TextField("Impact metric — e.g. 27 steps → 2 hours", text: $impactMetric)
                    .onSubmit(commitDetails)
                TextField("Tech — comma-separated", text: $techText)
                    .onSubmit(commitDetails)
                TextField("Strength notes — your STAR context, never on the CV",
                          text: $strengthNotes, axis: .vertical)
                    .lineLimit(3...8)
                if detailsDirty {
                    Button("Save depth", action: commitDetails)
                }
            }
            .listRowBackground(Color.paperRaised)
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.paper)
    }

    private func commitText() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            text = achievement.text
            return
        }
        try? store.updateAchievementText(achievement, to: trimmed)
        text = achievement.text
    }

    private func commitDetails() {
        let impact = impactMetric.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = strengthNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let tech = techText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        try? store.updateAchievementDetails(
            achievement,
            impactMetric: impact.isEmpty ? nil : impact,
            tech: tech,
            strengthNotes: notes.isEmpty ? nil : notes
        )
        impactMetric = achievement.impactMetric ?? ""
        techText = achievement.tech.joined(separator: ", ")
        strengthNotes = achievement.strengthNotes ?? ""
    }

    private func addTag() {
        let name = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        try? store.tag(achievement, skillNamed: name)
        newTag = ""
    }

    private func removeTag(named name: String) {
        guard let tag = achievement.skills.first(where: { $0.name == name }) else { return }
        try? store.untag(achievement, tag: tag)
    }
}

private struct RoleDetailPane: View {
    @Bindable var store: ProfileStore
    let role: Role

    @State private var company: String
    @State private var title: String
    @State private var start: Date
    @State private var isCurrent: Bool
    @State private var end: Date

    init(store: ProfileStore, role: Role) {
        self.store = store
        self.role = role
        _company = State(initialValue: role.company)
        _title = State(initialValue: role.title)
        _start = State(initialValue: role.start)
        _isCurrent = State(initialValue: role.end == nil)
        _end = State(initialValue: role.end ?? .now)
    }

    var body: some View {
        Form {
            Section("Role") {
                TextField("Title", text: $title)
                    .onSubmit(commit)
                TextField("Company", text: $company)
                    .onSubmit(commit)
                DatePicker("Started", selection: $start, displayedComponents: .date)
                Toggle("Current role", isOn: $isCurrent)
                if !isCurrent {
                    DatePicker("Ended", selection: $end, displayedComponents: .date)
                }
            }
            .listRowBackground(Color.paperRaised)
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.paper)
        .onChange(of: start) { commit() }
        .onChange(of: isCurrent) { commit() }
        .onChange(of: end) { commit() }
    }

    private func commit() {
        try? store.updateRole(
            role,
            company: company.trimmingCharacters(in: .whitespaces),
            title: title.trimmingCharacters(in: .whitespaces),
            start: start,
            end: isCurrent ? nil : end
        )
    }
}

private struct EducationDetailPane: View {
    @Bindable var store: ProfileStore
    let education: Education

    @State private var institution: String
    @State private var qualification: String
    @State private var start: Date
    @State private var isInProgress: Bool
    @State private var end: Date
    @State private var detail: String

    init(store: ProfileStore, education: Education) {
        self.store = store
        self.education = education
        _institution = State(initialValue: education.institution)
        _qualification = State(initialValue: education.qualification)
        _start = State(initialValue: education.start)
        _isInProgress = State(initialValue: education.end == nil)
        _end = State(initialValue: education.end ?? .now)
        _detail = State(initialValue: education.detail)
    }

    var body: some View {
        Form {
            Section("Education") {
                TextField("Institution", text: $institution)
                    .onSubmit(commit)
                TextField("Qualification — e.g. BSc Computer Science", text: $qualification)
                    .onSubmit(commit)
                DatePicker("Started", selection: $start, displayedComponents: .date)
                Toggle("In progress", isOn: $isInProgress)
                if !isInProgress {
                    DatePicker("Ended", selection: $end, displayedComponents: .date)
                }
                TextField("Detail — e.g. First-class honours", text: $detail)
                    .onSubmit(commit)
            }
            .listRowBackground(Color.paperRaised)
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.paper)
        .onChange(of: start) { commit() }
        .onChange(of: isInProgress) { commit() }
        .onChange(of: end) { commit() }
    }

    private func commit() {
        try? store.updateEducation(
            education,
            institution: institution.trimmingCharacters(in: .whitespaces),
            qualification: qualification.trimmingCharacters(in: .whitespaces),
            start: start,
            end: isInProgress ? nil : end,
            detail: detail.trimmingCharacters(in: .whitespaces)
        )
    }
}

private struct ProjectDetailPane: View {
    @Bindable var store: ProfileStore
    let project: Project

    @State private var name: String
    @State private var link: String
    @State private var summary: String

    init(store: ProfileStore, project: Project) {
        self.store = store
        self.project = project
        _name = State(initialValue: project.name)
        _link = State(initialValue: project.link)
        _summary = State(initialValue: project.summary)
    }

    /// Read-only rollup — tags live on the project's points.
    private var pointTagNames: [String] {
        Array(Set(project.points.flatMap { $0.skills.map(\.name) })).sorted()
    }

    var body: some View {
        Form {
            Section("Project") {
                TextField("Name", text: $name)
                    .onSubmit(commit)
                TextField("Link", text: $link)
                    .onSubmit(commit)
                TextField("Summary — one line", text: $summary, axis: .vertical)
                    .lineLimit(2...4)
                    .onSubmit(commit)
                if name != project.name || link != project.link || summary != project.summary {
                    Button("Save project", action: commit)
                }
            }
            .listRowBackground(Color.paperRaised)

            if !pointTagNames.isEmpty {
                Section("Tags across its points") {
                    TagChipsView(names: pointTagNames)
                }
                .listRowBackground(Color.paperRaised)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.paper)
    }

    private func commit() {
        try? store.updateProject(
            project,
            name: name.trimmingCharacters(in: .whitespaces),
            link: link.trimmingCharacters(in: .whitespaces),
            summary: summary.trimmingCharacters(in: .whitespaces)
        )
    }
}

#Preview("Point focused") {
    let store = try! ProfileStore(container: ProfileStore.container(inMemory: true))
    try! store.createProfile(name: "Alex Climber", headline: "Staff Engineer")
    let role = try! store.addRole(company: "Acme", title: "Senior Engineer", start: .now, end: nil)
    let point = try! store.addAchievement(to: role, text: "Won the first internal AI Olympiad")
    try! store.tag(point, skillNamed: "AI Engineering")
    return ProfileDetailRail(store: store, focus: .constant(.point(point)))
        .frame(width: 300, height: 600)
}

#Preview("Nothing focused") {
    let store = try! ProfileStore(container: ProfileStore.container(inMemory: true))
    try! store.createProfile(name: "Alex Climber", headline: "Staff Engineer")
    return ProfileDetailRail(store: store, focus: .constant(nil))
        .frame(width: 300, height: 600)
}

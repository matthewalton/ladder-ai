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
        .safeAreaInset(edge: .bottom) {
            if focus != nil {
                deleteBar
            }
        }
    }

    /// The rail's visible delete affordance for whatever is focused — the
    /// discoverable sibling of the rows' hover and context-menu deletes.
    private var deleteBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button(role: .destructive, action: deleteFocused) {
                Label(deleteLabel, systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Color.clay)
            .padding(12)
        }
        .background(Color.paper)
    }

    private var deleteLabel: String {
        switch focus {
        case .point: "Delete point"
        case .role: "Delete role"
        case .education: "Delete education"
        case .project: "Delete project"
        case nil: ""
        }
    }

    private func deleteFocused() {
        let focused = focus
        focus = nil
        switch focused {
        case .point(let achievement):
            try? store.deleteAchievement(achievement)
        case .role(let role):
            try? store.deleteRole(role)
        case .education(let education):
            try? store.deleteEducation(education)
        case .project(let project):
            try? store.deleteProject(project)
        case nil:
            break
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

// MARK: - Rail building blocks

/// The rail's scrollable pane chrome shared by every focused editor.
private struct RailPane<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.paper)
    }
}

/// A rail section: uppercase header above its fields.
private struct RailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ProfileSectionHeader(title: title)
            content
        }
    }
}

/// A labelled rail input: caption label above the field, never beside it —
/// the rail is too narrow for label/value columns.
private struct RailField<Input: View>: View {
    let label: String
    @ViewBuilder let input: Input

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.inkSoft)
            input
        }
    }
}

/// The rail's input chrome: a visibly bordered, clickable field that shows a
/// Pine ring while focused.
private struct RailInputChrome: ViewModifier {
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(.callout)
            .foregroundStyle(Color.ink)
            .focused($isFocused)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(isFocused ? Color.pine : Color.mist, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

extension View {
    fileprivate func railInput() -> some View {
        modifier(RailInputChrome())
    }
}

/// The small save affordance shown while a rail section has unsaved edits.
private struct RailSaveButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.borderedProminent)
            .tint(Color.pine)
            .controlSize(.small)
    }
}

// MARK: - Panes

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
        RailPane {
            RailSection(title: "Point") {
                TextField("A brief key talking point", text: $text, axis: .vertical)
                    .lineLimit(3...8)
                    .onSubmit(commitText)
                    .railInput()
                if text != achievement.text {
                    RailSaveButton(title: "Save wording", action: commitText)
                }
            }

            RailSection(title: "Tags") {
                if !achievement.skills.isEmpty {
                    TagChipsView(names: achievement.skills.map(\.name).sorted()) { name in
                        removeTag(named: name)
                    }
                }
                TextField("Add a tag", text: $newTag)
                    .onSubmit(addTag)
                    .railInput()
            }

            RailSection(title: "Depth") {
                RailField(label: "Impact metric") {
                    TextField("e.g. 27 steps → 2 hours", text: $impactMetric)
                        .onSubmit(commitDetails)
                        .railInput()
                }
                RailField(label: "Tech — comma-separated") {
                    TextField("e.g. Swift, SwiftData", text: $techText)
                        .onSubmit(commitDetails)
                        .railInput()
                }
                RailField(label: "Strength notes — never on the CV") {
                    TextField("Your STAR context", text: $strengthNotes, axis: .vertical)
                        .lineLimit(3...8)
                        .railInput()
                }
                if detailsDirty {
                    RailSaveButton(title: "Save depth", action: commitDetails)
                }
            }
        }
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
        RailPane {
            RailSection(title: "Role") {
                RailField(label: "Title") {
                    TextField("e.g. Senior Engineer", text: $title)
                        .onSubmit(commit)
                        .railInput()
                }
                RailField(label: "Company") {
                    TextField("Company", text: $company)
                        .onSubmit(commit)
                        .railInput()
                }
                RailField(label: "Started") {
                    DatePicker("Started", selection: $start, displayedComponents: .date)
                        .labelsHidden()
                }
                Toggle("Current role", isOn: $isCurrent)
                    .font(.callout)
                    .foregroundStyle(Color.ink)
                if !isCurrent {
                    RailField(label: "Ended") {
                        DatePicker("Ended", selection: $end, displayedComponents: .date)
                            .labelsHidden()
                    }
                }
            }
        }
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
        RailPane {
            RailSection(title: "Education") {
                RailField(label: "Institution") {
                    TextField("Institution", text: $institution)
                        .onSubmit(commit)
                        .railInput()
                }
                RailField(label: "Qualification") {
                    TextField("e.g. BSc Computer Science", text: $qualification)
                        .onSubmit(commit)
                        .railInput()
                }
                RailField(label: "Started") {
                    DatePicker("Started", selection: $start, displayedComponents: .date)
                        .labelsHidden()
                }
                Toggle("In progress", isOn: $isInProgress)
                    .font(.callout)
                    .foregroundStyle(Color.ink)
                if !isInProgress {
                    RailField(label: "Ended") {
                        DatePicker("Ended", selection: $end, displayedComponents: .date)
                            .labelsHidden()
                    }
                }
                RailField(label: "Detail") {
                    TextField("e.g. First-class honours", text: $detail)
                        .onSubmit(commit)
                        .railInput()
                }
            }
        }
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
    @State private var details: String
    @State private var newTag = ""

    init(store: ProfileStore, project: Project) {
        self.store = store
        self.project = project
        _name = State(initialValue: project.name)
        _link = State(initialValue: project.link)
        _summary = State(initialValue: project.summary)
        _details = State(initialValue: project.details)
    }

    private var dirty: Bool {
        name != project.name || link != project.link
            || summary != project.summary || details != project.details
    }

    var body: some View {
        RailPane {
            RailSection(title: "Project") {
                RailField(label: "Name") {
                    TextField("Name", text: $name)
                        .onSubmit(commit)
                        .railInput()
                }
                RailField(label: "Link") {
                    TextField("https://…", text: $link)
                        .onSubmit(commit)
                        .railInput()
                }
                RailField(label: "Summary — one line") {
                    TextField("Summary", text: $summary, axis: .vertical)
                        .lineLimit(2...4)
                        .onSubmit(commit)
                        .railInput()
                }
                RailField(label: "Description — how you'd tell it on a CV") {
                    TextField("Description", text: $details, axis: .vertical)
                        .lineLimit(4...12)
                        .railInput()
                }
                if dirty {
                    RailSaveButton(title: "Save project", action: commit)
                }
            }

            RailSection(title: "Tags") {
                if !project.skills.isEmpty {
                    TagChipsView(names: project.skills.map(\.name).sorted()) { name in
                        removeTag(named: name)
                    }
                }
                TextField("Add a tag", text: $newTag)
                    .onSubmit(addTag)
                    .railInput()
            }
        }
    }

    private func commit() {
        try? store.updateProject(
            project,
            name: name.trimmingCharacters(in: .whitespaces),
            link: link.trimmingCharacters(in: .whitespaces),
            summary: summary.trimmingCharacters(in: .whitespaces),
            details: details.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func addTag() {
        let name = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        try? store.tag(project, skillNamed: name)
        newTag = ""
    }

    private func removeTag(named name: String) {
        guard let tag = project.skills.first(where: { $0.name == name }) else { return }
        try? store.untag(project, tag: tag)
    }
}

#Preview("Point focused") {
    let store = try! ProfileStore(container: ProfileStore.container(inMemory: true))
    try! store.createProfile(name: "Alex Climber", headline: "Staff Engineer")
    let role = try! store.addRole(company: "Acme", title: "Senior Engineer", start: .now, end: nil)
    let point = try! store.addAchievement(to: role, text: "Won the first internal AI Olympiad")
    try! store.tag(point, skillNamed: "AI Engineering")
    try! store.tag(point, skillNamed: "cross-functional delivery")
    return ProfileDetailRail(store: store, focus: .constant(.point(point)))
        .frame(width: 300, height: 600)
}

#Preview("Role focused") {
    let store = try! ProfileStore(container: ProfileStore.container(inMemory: true))
    try! store.createProfile(name: "Alex Climber", headline: "Staff Engineer")
    let role = try! store.addRole(company: "Acme", title: "Senior Engineer", start: .now, end: nil)
    return ProfileDetailRail(store: store, focus: .constant(.role(role)))
        .frame(width: 300, height: 600)
}

#Preview("Nothing focused") {
    let store = try! ProfileStore(container: ProfileStore.container(inMemory: true))
    try! store.createProfile(name: "Alex Climber", headline: "Staff Engineer")
    return ProfileDetailRail(store: store, focus: .constant(nil))
        .frame(width: 300, height: 600)
}

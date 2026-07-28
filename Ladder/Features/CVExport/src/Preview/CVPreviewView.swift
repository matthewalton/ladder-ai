import PDFKit
import SwiftData
import SwiftUI

struct CVPreviewView: View {
    @Bindable var model: CVPreviewModel
    var onExport: () -> Void
    var onClose: () -> Void

    var body: some View {
        HSplitView {
            CVPagesView(data: model.pdfData)
                .frame(minWidth: 420)
            editor
                .frame(minWidth: 320, idealWidth: 380)
        }
        .safeAreaInset(edge: .bottom) { footer }
        .background(Color.paper)
        .alert("Discard your changes to this CV?", isPresented: confirmingDiscard) {
            Button("Keep editing", role: .cancel) { model.cancelDiscard() }
            Button("Discard", role: .destructive) {
                model.confirmDiscard()
                onClose()
            }
        } message: {
            Text("Edits here apply to this application only and aren't saved. Tags you added stay on your Profile.")
        }
    }

    private var confirmingDiscard: Binding<Bool> {
        Binding(get: { model.isConfirmingDiscard }, set: { if !$0 { model.cancelDiscard() } })
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            Label(pageSummary, systemImage: "doc.on.doc")
                .font(.caption)
                .foregroundStyle(model.canExport ? Color.inkSoft : Color.clay)
            Label(coverageSummary, systemImage: "target")
                .font(.caption)
                .foregroundStyle(Color.inkSoft)
            Spacer()
            Button("Close") {
                model.requestClose()
                if model.isClosed { onClose() }
            }
            Button("Export CV…", action: onExport)
                .buttonStyle(.borderedProminent)
                .tint(Color.pine)
                .disabled(!model.canExport)
        }
        .padding(12)
        .background(Color.paperRaised)
    }

    private var pageSummary: String {
        guard !model.canExport else {
            return model.pageCount == 1 ? "1 page" : "\(model.pageCount) pages"
        }
        let over = model.pagesOverCap
        return "\(model.pageCount) pages — about \(over) page\(over == 1 ? "" : "s") over. Untick or shorten something to export."
    }

    private var coverageSummary: String {
        "Covers \(model.coverage.carried.count) of \(model.coverage.matchedCount) matched tags"
    }

    // MARK: - Editing surface

    private var editor: some View {
        List {
            fitReportSection
            coverageSection
            summarySection
            headerSection
            ForEach(model.profile.roles.sorted { $0.start > $1.start }, id: \.persistentModelID) {
                role in
                roleSection(role)
            }
            projectsSection
            skillsSection
            educationSection
            interestsSection
        }
        .scrollContentBackground(.hidden)
    }

    private var fitReportSection: some View {
        Group {
            Section("Why these were selected") {
                Text(model.fitReport.rationale)
                    .font(.trailNarrative())
                    .foregroundStyle(Color.ink)
                    .padding(.vertical, 4)
            }
            if !model.fitReport.gaps.isEmpty {
                Section("Gaps") {
                    ForEach(model.fitReport.gaps, id: \.self) { gap in
                        chip(gap, icon: "exclamationmark.circle", tint: Color.clay)
                    }
                }
            }
            if !model.fitReport.trimmed.isEmpty {
                Section("Trimmed to fit two pages") {
                    ForEach(model.fitReport.trimmed, id: \.self) { item in
                        chip(item, icon: "scissors", tint: Color.inkSoft)
                    }
                }
            }
        }
    }

    private var coverageSection: some View {
        Section("Coverage") {
            Text("How much of this job's matched tags the points on this CV carry. Your Match score doesn't move with editing — it scores your whole Profile against the job.")
                .font(.caption)
                .foregroundStyle(Color.inkSoft)
            if !model.coverage.carried.isEmpty {
                chip(model.coverage.carried.joined(separator: " · "),
                     icon: "checkmark.circle", tint: Color.pine)
            }
            if !model.coverage.uncovered.isEmpty {
                chip(model.coverage.uncovered.joined(separator: " · "),
                     icon: "tag.slash", tint: Color.clay)
            }
            Button("Refresh relevance scores") { Task { await model.rescore() } }
                .disabled(model.isRescoring)
            if let failure = model.rescoreFailure {
                Text(failure)
                    .font(.caption)
                    .foregroundStyle(Color.clay)
            }
        }
    }

    private var summarySection: some View {
        Section("CV summary") {
            TextEditor(text: summaryBinding)
                .font(.callout)
                .frame(minHeight: 60)
                .scrollContentBackground(.hidden)
        }
    }

    private var summaryBinding: Binding<String> {
        Binding(get: { model.summary }, set: { model.rewordSummary(to: $0) })
    }

    private var headerSection: some View {
        Section("Header") {
            Text(model.profile.name)
                .font(.body)
                .foregroundStyle(Color.ink)
            if !model.profile.headline.isEmpty {
                keepToggle(model.profile.headline, isKept: !model.isHeadlineRemoved) {
                    model.setHeadlineRemoved(!$0)
                }
            }
            ForEach(contactLines, id: \.self) { line in
                keepToggle(line, isKept: !model.isRemoved(contactLine: line)) {
                    model.setRemoved(contactLine: line, !$0)
                }
            }
        }
    }

    private var contactLines: [String] {
        [
            model.profile.contact.email, model.profile.contact.phone,
            model.profile.contact.location, model.profile.contact.link,
        ].filter { !$0.isEmpty }
    }

    private func roleSection(_ role: Role) -> some View {
        Section("\(role.title) — \(role.company)") {
            keepToggle(
                "Show this role on the CV", isKept: !model.isRemoved(role),
                help: "Leaving a role off can read as an employment gap to an applicant tracking system."
            ) { model.setRemoved(role, !$0) }
            if !model.isRemoved(role) {
                ForEach(role.orderedAchievements, id: \.persistentModelID) { achievement in
                    bulletRow(achievement)
                }
            }
        }
    }

    private func bulletRow(_ achievement: Achievement) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(
                isOn: Binding(
                    get: { model.isSelected(achievement) },
                    set: { model.setSelected(achievement, $0) })
            ) {
                Text(achievement.title ?? achievement.text)
                    .font(.body)
                    .foregroundStyle(Color.ink)
            }
            .toggleStyle(.checkbox)
            if model.isSelected(achievement) {
                TextField(
                    "Bullet",
                    text: Binding(
                        get: { model.wording(of: achievement) },
                        set: { model.reword(achievement, to: $0) }),
                    axis: .vertical
                )
                .textFieldStyle(.roundedBorder)
                .font(.callout)
                RelevanceLine(stats: model.relevanceStats(for: achievement))
                if model.relevanceStats(for: achievement) == nil {
                    Text("Not scored yet")
                        .font(.caption)
                        .foregroundStyle(Color.inkSoft)
                }
                TagEntry { name in try? model.applyTag(named: name, to: achievement) }
            }
        }
        .padding(.vertical, 2)
    }

    private var projectsSection: some View {
        Section("Projects") {
            ForEach(model.profile.orderedProjects, id: \.persistentModelID) { project in
                Toggle(
                    isOn: Binding(
                        get: { model.isSelected(project) },
                        set: { model.setSelected(project, $0) })
                ) {
                    Text(project.name.isEmpty ? "Project" : project.name)
                        .font(.body)
                        .foregroundStyle(Color.ink)
                }
                .toggleStyle(.checkbox)
            }
        }
    }

    private var skillsSection: some View {
        Section("Skills") {
            ForEach(model.review.skillCategories, id: \.name) { category in
                keepToggle(category.name, isKept: !model.isDropped(category: category.name)) {
                    model.setDropped(category: category.name, !$0)
                }
                if !model.isDropped(category: category.name) {
                    ForEach(category.skills, id: \.self) { skill in
                        keepToggle(skill, isKept: !model.isDropped(skill: skill)) {
                            model.setDropped(skill: skill, !$0)
                        }
                        .padding(.leading, 20)
                    }
                }
            }
        }
    }

    private var educationSection: some View {
        Section("Education") {
            ForEach(model.profile.orderedEducation, id: \.persistentModelID) { entry in
                keepToggle(
                    "\(entry.qualification), \(entry.institution)", isKept: !model.isRemoved(entry)
                ) { model.setRemoved(entry, !$0) }
            }
        }
    }

    private var interestsSection: some View {
        Section("Interests") {
            ForEach(model.profile.interests, id: \.self) { interest in
                keepToggle(interest, isKept: !model.isRemoved(interest: interest)) {
                    model.setRemoved(interest: interest, !$0)
                }
            }
        }
    }

    // MARK: - Pieces

    private func keepToggle(
        _ label: String, isKept: Bool, help: String? = nil, set: @escaping (Bool) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(isOn: Binding(get: { isKept }, set: set)) {
                Text(label)
                    .font(.callout)
                    .foregroundStyle(Color.ink)
            }
            .toggleStyle(.checkbox)
            if let help {
                Text(help)
                    .font(.caption)
                    .foregroundStyle(Color.inkSoft)
                    .padding(.leading, 20)
            }
        }
    }

    private func chip(_ text: String, icon: String, tint: Color) -> some View {
        Label {
            Text(text)
                .font(.callout)
                .foregroundStyle(Color.ink)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(tint)
        }
        .padding(.vertical, 2)
    }
}

private struct TagEntry: View {
    var onSubmit: (String) -> Void
    @State private var name = ""

    var body: some View {
        HStack(spacing: 6) {
            TextField("Add a tag this point evidences", text: $name)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .onSubmit(submit)
            Button("Tag", action: submit)
                .font(.caption)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func submit() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onSubmit(trimmed)
        name = ""
    }
}

/// The rendered pages themselves, never a second SwiftUI arrangement of the
/// same content that could drift from what exports.
struct CVPagesView: NSViewRepresentable {
    var data: Data

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.document = PDFDocument(data: data)
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        guard view.document?.dataRepresentation() != data else { return }
        view.document = PDFDocument(data: data)
    }
}

#Preview {
    let profileStore = try! ProfileStore(container: ProfileStore.container(inMemory: true))
    try! profileStore.load()
    try! profileStore.createProfile(name: "Alex Climber", headline: "Staff Engineer")
    let role = try! profileStore.addRole(
        company: "Acme", title: "Senior Engineer",
        start: Date(timeIntervalSince1970: 1_600_000_000), end: nil)
    let achievement = try! profileStore.addAchievement(
        to: role, text: "Cut CI build times across every product target")
    try! profileStore.tag(achievement, skillNamed: "CI/CD")
    let profile = profileStore.profile!
    let result = try! TailorResult(
        json: Data("""
        {
          "summary": "Senior engineer focused on CI performance at platform scale.",
          "selections": [
            {"achievementID": "a1", "bullet": "Drove CI build times down across every product target"}
          ],
          "skillCategories": [{"name": "Platform Engineering", "skills": ["CI/CD"]}],
          "relevance": {"a1": {"tech": 5, "domain": 4, "seniority": 3, "impact": 4}},
          "gaps": ["The JD asks for Kubernetes; nothing on file mentions it"],
          "rationale": "CI work maps directly to the JD's platform focus."
        }
        """.utf8),
        validAchievementIDs: ["a1"],
        tagNamesByID: ["a1": ["CI/CD"]],
        matchedTagNames: ["CI/CD", "Kubernetes"]
    )
    let review = TailorReview(
        result: result, achievementsByID: ["a1": achievement],
        matchedTagNames: ["CI/CD", "Kubernetes"])
    let context = ModelContext(profileStore.container)
    let application = Application(
        company: "Summit Labs", roleTitle: "Platform Engineer",
        jobDescription: "Own platform reliability.", status: .draft)
    context.insert(application)
    try! context.save()
    let document = CVDocument(profile: profile, review: review)
    let settings = CVFitLoop.settings(for: document, stretching: true)
    let composition = CVComposition(
        fit: CVFitLoop.Outcome(
            document: document, metrics: settings.metrics, pageCount: settings.pageCount,
            trimmedItems: [],
            fitMetrics: FitMetrics(
                roleCount: 1, bulletCount: 1, projectCount: 0, skillCount: 1,
                characterCount: 120, compactionStep: settings.stepIndex,
                stretchFactor: Double(settings.stretch), condensePassRun: false,
                trimPassCount: 0, trimmedItemCount: 0,
                naturalPageCount: settings.pageCount, finalPageCount: settings.pageCount)),
        outcome: review.outcome)
    return CVPreviewView(
        model: CVPreviewModel(
            profileStore: profileStore,
            profile: profile,
            review: review,
            applicationID: application.persistentModelID,
            jobDescription: application.jobDescription,
            composition: composition
        ),
        onExport: {},
        onClose: {}
    )
    .frame(width: 1000, height: 700)
}

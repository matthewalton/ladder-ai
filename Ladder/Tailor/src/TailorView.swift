import SwiftUI

struct TailorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store: TailorStore
    @State private var exportStore: CVExportStore
    @State private var export: CVExportStore.Export?
    @State private var isSavingPDF = false
    @State private var exportFailed = false

    private let profileStore: ProfileStore
    private let application: Application
    private let details: JobDetails

    /// Always presented for an application ([TAILOR-23], decisions/0008):
    /// its stored details are the run's input — there is no input form.
    init(
        profileStore: ProfileStore,
        application: Application,
        keyStore: any APIKeyStore = KeychainAPIKeyStore(),
        makeIntelligence: ((String) -> any IntelligenceService)? = nil
    ) {
        self.profileStore = profileStore
        self.application = application
        details = JobDetails(application: application)
        _exportStore = State(initialValue: CVExportStore(container: profileStore.container))
        if let makeIntelligence {
            _store = State(initialValue: TailorStore(
                profileStore: profileStore, keyStore: keyStore, makeIntelligence: makeIntelligence
            ))
        } else {
            _store = State(initialValue: TailorStore(
                profileStore: profileStore, keyStore: keyStore
            ))
        }
    }

    var body: some View {
        Group {
            switch store.phase {
            case .idle, .running:
                // The run starts on presentation via `.task` — idle is the
                // instant before it kicks off.
                progress("Matching your points to the job…")
            case .review:
                if let export {
                    FitReportView(report: export.fitReport, onDone: { dismiss() })
                } else if let review = store.review {
                    TailorReviewView(
                        review: review,
                        onCancel: { startRun() },
                        onDone: { dismiss() },
                        onExport: { runExport(review: review) }
                    )
                }
            case .failed(let error):
                failed(error)
            }
        }
        .task {
            if store.phase == .idle {
                await store.startRun(details)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .background(Color.paper)
        .fileExporter(
            isPresented: $isSavingPDF,
            document: export.map { PDFFileDocument(data: $0.pdfData) },
            contentType: .pdf,
            defaultFilename: defaultFilename
        ) { _ in
            // Declining the save does not undo the persisted Application;
            // the fit report shows either way.
        }
        .alert("The CV couldn't be exported.", isPresented: $exportFailed) {
            Button("OK", role: .cancel) {}
        }
    }

    private func startRun() {
        Task { await store.startRun(details) }
    }

    private func runExport(review: TailorReview) {
        guard let profile = profileStore.profile else { return }
        do {
            // Into this application ([CVEXPORT-22]) — the CV attaches where
            // the run started.
            export = try exportStore.export(
                profile: profile, review: review, into: application.persistentModelID)
            isSavingPDF = true
        } catch {
            exportFailed = true
        }
    }

    private var defaultFilename: String {
        let name = [profileStore.profile?.name ?? "", details.roleTitle]
            .filter { !$0.isEmpty }
            .joined(separator: " — ")
        return name.isEmpty ? "CV" : name
    }

    private func progress(_ message: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(message)
                .font(.callout)
                .foregroundStyle(Color.inkSoft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failed(_ error: TailorError) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(Color.clay)
            Text(message(for: error))
                .font(.callout)
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
            HStack {
                if error == .apiKeyRequired {
                    SettingsLink {
                        Text("Open Settings…")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.pine)
                    Button("Close") { dismiss() }
                } else {
                    Button("Try again") { startRun() }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.pine)
                    Button("Close") { dismiss() }
                }
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func message(for error: TailorError) -> String {
        switch error {
        case .jobDescriptionRequired:
            "This application has no job description yet. Add or import one on its detail, then Create CV again."
        case .achievementsRequired:
            "There's nothing to select from yet. Add achievements to your Profile, or import your CV."
        case .apiKeyRequired:
            "Tailoring needs your Anthropic API key. Add it in Settings — it's stored only in your Keychain."
        case .resultInvalid:
            "The tailor result didn't come back in a shape Ladder could read, even after one repair. Nothing was changed."
        case .requestFailed:
            "The request couldn't be completed. Check your connection and try again."
        }
    }
}

struct TailorReviewView: View {
    @Bindable var review: TailorReview
    var onCancel: () -> Void
    var onDone: () -> Void
    var onExport: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            List {
                if !review.summary.isEmpty {
                    Section("CV summary") {
                        Text(review.summary)
                            .font(.callout)
                            .foregroundStyle(Color.ink)
                            .padding(.vertical, 2)
                    }
                }
                Section("Why these were selected") {
                    Text(review.rationale)
                        .font(.callout)
                        .foregroundStyle(Color.ink)
                        .padding(.vertical, 2)
                }
                if !review.gaps.isEmpty {
                    Section("Gaps") {
                        ForEach(review.gaps, id: \.self) { gap in
                            Label {
                                Text(gap)
                                    .font(.callout)
                                    .foregroundStyle(Color.ink)
                            } icon: {
                                Image(systemName: "exclamationmark.circle")
                                    .foregroundStyle(Color.clay)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                ForEach(groupedItems, id: \.label) { group in
                    Section(group.label) {
                        ForEach(group.items) { item in
                            ReviewedBulletRow(item: item)
                        }
                    }
                }
                if !review.selectedProjects.isEmpty {
                    // Whole units, as they stand on the Profile — nothing to
                    // accept or reject per project (decisions/0007).
                    Section("Projects on this CV") {
                        ForEach(review.selectedProjects, id: \.persistentModelID) { project in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(project.name.isEmpty ? "Project" : project.name)
                                    .font(.body)
                                    .foregroundStyle(Color.ink)
                                if !project.details.isEmpty {
                                    Text(project.details)
                                        .font(.caption)
                                        .foregroundStyle(Color.inkSoft)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)

            Divider()
            HStack {
                Text("Rejected bullets fall back to your own brief point — the canon stays yours.")
                    .font(.caption)
                    .foregroundStyle(Color.inkSoft)
                Spacer()
                Button("Start over", action: onCancel)
                Button("Done", action: onDone)
                Button("Export CV…", action: onExport)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.pine)
            }
            .padding(12)
            .background(Color.paperRaised)
        }
    }

    /// Review items grouped under the role the point belongs to, in
    /// selection order; selected projects list as whole units beneath.
    private var groupedItems: [(label: String, items: [ReviewedBullet])] {
        var order: [String] = []
        var groups: [String: [ReviewedBullet]] = [:]
        for item in review.items {
            let label = parentLabel(for: item.achievement)
            if groups[label] == nil { order.append(label) }
            groups[label, default: []].append(item)
        }
        return order.map { (label: $0, items: groups[$0] ?? []) }
    }

    private func parentLabel(for achievement: Achievement) -> String {
        guard let role = achievement.role else { return "Profile" }
        return "\(role.title) — \(role.company)"
    }
}

private struct ReviewedBulletRow: View {
    @Bindable var item: ReviewedBullet

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $item.accepted) {
                Text(item.bullet)
                    .font(.body)
                    .foregroundStyle(Color.ink)
            }
            .toggleStyle(.checkbox)

            HStack(alignment: .top, spacing: 4) {
                Text("Your point:")
                    .font(.caption)
                    .foregroundStyle(Color.inkSoft)
                Text(item.achievement.text)
                    .font(.caption)
                    .foregroundStyle(Color.inkSoft)
            }
            .padding(.leading, 20)
        }
        .padding(.vertical, 4)
    }
}

#Preview("Tailor run") {
    let profileStore = try! ProfileStore(container: ProfileStore.container(inMemory: true))
    try! profileStore.createProfile(name: "Alex Climber", headline: "Staff Engineer")
    let role = try! profileStore.addRole(company: "Acme", title: "Senior Engineer", start: .now, end: nil)
    try! profileStore.addAchievement(to: role, text: "Cut CI build times across every product target")
    let application = Application(
        company: "Summit Labs", roleTitle: "Platform Engineer",
        jobDescription: "Own platform reliability. Kubernetes, CI at scale, incident response.",
        status: .draft
    )
    return TailorView(
        profileStore: profileStore,
        application: application,
        keyStore: InMemoryAPIKeyStore(key: "sk-preview"),
        makeIntelligence: { _ in FixtureIntelligenceService.tailorFixture() }
    )
}

#Preview("Review") {
    let profileStore = try! ProfileStore(container: ProfileStore.container(inMemory: true))
    try! profileStore.createProfile(name: "Alex Climber", headline: "Staff Engineer")
    let role = try! profileStore.addRole(company: "Acme", title: "Senior Engineer", start: .now, end: nil)
    let achievement = try! profileStore.addAchievement(
        to: role, text: "Cut CI build times across every product target"
    )
    let result = try! TailorResult(
        json: Data("""
        {
          "summary": "Senior engineer focused on CI performance at platform scale.",
          "selections": [
            {"achievementID": "a1", "bullet": "Drove CI build times down across every product target"}
          ],
          "gaps": ["The JD asks for Kubernetes; nothing on file mentions it"],
          "rationale": "CI work maps directly to the JD's platform focus."
        }
        """.utf8),
        validAchievementIDs: ["a1"]
    )
    let review = TailorReview(result: result, achievementsByID: ["a1": achievement])
    return TailorReviewView(review: review, onCancel: {}, onDone: {})
        .frame(width: 640, height: 480)
}

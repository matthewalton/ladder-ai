import SwiftData
import SwiftUI

struct TailorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var flow: TailorFlowStore
    @State private var hasStarted = false
    @State private var exportStore: CVExportStore
    @State private var export: CVExportStore.Export?
    @State private var isSavingPDF = false
    @State private var exportFailed = false

    private let profileStore: ProfileStore
    private let application: Application
    private let details: JobDetails
    private let keyStore: any APIKeyStore
    private let makeIntelligence: ((String) -> any IntelligenceService)?

    /// Always presented for an application ([TAILOR-23], decisions/0008):
    /// its stored details are the flow's input — there is no input form.
    /// The flow scans first, holds in the Match review, and tailors only
    /// after confirmation ([TAILOR-43], [TAILOR-45]).
    init(
        profileStore: ProfileStore,
        application: Application,
        keyStore: any APIKeyStore = KeychainAPIKeyStore(),
        makeIntelligence: ((String) -> any IntelligenceService)? = nil
    ) {
        self.profileStore = profileStore
        self.application = application
        self.keyStore = keyStore
        self.makeIntelligence = makeIntelligence
        details = JobDetails(application: application)
        _exportStore = State(initialValue: CVExportStore(container: profileStore.container))
        if let makeIntelligence {
            _flow = State(initialValue: TailorFlowStore(
                profileStore: profileStore, application: application, keyStore: keyStore,
                makeIntelligence: makeIntelligence
            ))
        } else {
            _flow = State(initialValue: TailorFlowStore(
                profileStore: profileStore, application: application, keyStore: keyStore
            ))
        }
    }

    var body: some View {
        Group {
            switch flow.phase {
            case .scanning:
                progress("Scanning the job description against your tags…")
            case .matchReview:
                if let model = flow.matchReview {
                    MatchReviewView(
                        model: model,
                        onCancel: {
                            flow.cancelMatchReview()
                            dismiss()
                        },
                        onContinue: { Task { await flow.confirmMatchReview() } }
                    )
                }
            case .tailoring:
                progress("Matching your points to the job…")
            case .review:
                if let export {
                    FitReportView(report: export.fitReport, onDone: { dismiss() })
                } else if let review = flow.review {
                    TailorReviewView(
                        review: review,
                        onCancel: { retry() },
                        onDone: { dismiss() },
                        onExport: { runExport(review: review) }
                    )
                }
            case .scanFailed(let error):
                failed(message(for: error), needsKey: error == .apiKeyRequired)
            case .tailorFailed(let error):
                failed(message(for: error), needsKey: error == .apiKeyRequired)
            }
        }
        .task {
            if !hasStarted {
                hasStarted = true
                await flow.start()
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

    /// Retry re-runs from the scan (decisions/0014).
    private func retry() {
        Task { await flow.retry() }
    }

    private func runExport(review: TailorReview) {
        guard let profile = profileStore.profile else { return }
        Task {
            do {
                // Into this application ([CVEXPORT-22]) — the CV attaches
                // where the run started. The fit loop may need the condense
                // or trim pass (decisions/0008), built on the same service
                // the run used.
                export = try await exportStore.export(
                    profile: profile, review: review,
                    into: application.persistentModelID,
                    fitPasses: fitPassRunner())
                isSavingPDF = true
            } catch {
                exportFailed = true
            }
        }
    }

    private func fitPassRunner() -> FitPassRunner? {
        guard let key = try? keyStore.readKey(), !key.isEmpty else { return nil }
        let service = makeIntelligence?(key) ?? AnthropicIntelligenceService(apiKey: key)
        return FitPassRunner(service: service)
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

    private func failed(_ message: String, needsKey: Bool) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(Color.clay)
            Text(message)
                .font(.callout)
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
            HStack {
                if needsKey {
                    SettingsLink {
                        Text("Open Settings…")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.pine)
                    Button("Close") { dismiss() }
                } else {
                    Button("Try again") { retry() }
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

    /// A failed scan fails the whole flow — no raw-JD fallback
    /// (decisions/0014; [TAILOR-44]).
    private func message(for error: JDScanError) -> String {
        switch error {
        case .jobDescriptionRequired:
            "This application has no job description yet. Add or import one on its detail, then Create CV again."
        case .apiKeyRequired:
            "Tailoring needs your Anthropic API key. Add it in Settings — it's stored only in your Keychain."
        case .requestFailed(let detail):
            "The job description scan couldn't be completed (\(detail)). Check your connection and try again."
        case .responseTruncated:
            "The scan response was cut off before it finished. Try again."
        case .resultInvalid:
            "The scan result didn't come back in a shape Ladder could read, even after one repair. Nothing was changed."
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
                // The overlap view's uncovered remainder ([TAILOR-55]):
                // matched vocabulary the selection leaves unevidenced.
                if !review.uncoveredMatchedTags.isEmpty {
                    Section("Matched tags nothing selected covers") {
                        ForEach(review.uncoveredMatchedTags, id: \.self) { tag in
                            Label {
                                Text(tag)
                                    .font(.callout)
                                    .foregroundStyle(Color.ink)
                            } icon: {
                                Image(systemName: "tag.slash")
                                    .foregroundStyle(Color.clay)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                ForEach(groupedItems, id: \.label) { group in
                    Section(group.label) {
                        ForEach(group.items) { item in
                            ReviewedBulletRow(
                                item: item,
                                coveredTags: review.coveredMatchedTags(for: item.achievement))
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
                                CoveredTagsLine(tags: review.coveredMatchedTags(for: project))
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
    /// The matched Tags this point covers — the overlap view's per-point
    /// side ([TAILOR-54]).
    var coveredTags: [String] = []

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
            CoveredTagsLine(tags: coveredTags)
                .padding(.leading, 20)
        }
        .padding(.vertical, 4)
    }
}

/// "Covers: Kubernetes · Swift" — nothing at all when the point covers no
/// matched Tag ([TAILOR-54]).
struct CoveredTagsLine: View {
    var tags: [String]

    var body: some View {
        if !tags.isEmpty {
            HStack(alignment: .top, spacing: 4) {
                Text("Covers:")
                    .font(.caption)
                    .foregroundStyle(Color.inkSoft)
                Text(tags.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(Color.pine)
            }
        }
    }
}

#Preview("Tailor run") {
    let profileStore = try! ProfileStore(container: ProfileStore.container(inMemory: true))
    try! profileStore.createProfile(name: "Alex Climber", headline: "Staff Engineer")
    let role = try! profileStore.addRole(company: "Acme", title: "Senior Engineer", start: .now, end: nil)
    let achievement = try! profileStore.addAchievement(
        to: role, text: "Cut CI build times across every product target")
    try! profileStore.tag(achievement, skillNamed: "Swift")
    let kubernetes = try! profileStore.tag(achievement, skillNamed: "Kubernetes")
    try! profileStore.recordAlias("k8s", on: kubernetes)
    try! profileStore.tag(achievement, skillNamed: "SwiftUI")
    try! profileStore.tag(achievement, skillNamed: "Leadership")
    let context = ModelContext(profileStore.container)
    let application = Application(
        company: "Summit Labs", roleTitle: "Platform Engineer",
        jobDescription: "Own platform reliability. Kubernetes, CI at scale, incident response.",
        status: .draft
    )
    context.insert(application)
    try! context.save()
    // The flow scans first — sequence the canned scan then the tailor result.
    let scanData = try! Data(
        contentsOf: Bundle.main.url(forResource: "jd-scan", withExtension: "json", subdirectory: "Fixtures")!)
    let tailorData = try! Data(
        contentsOf: Bundle.main.url(forResource: "tailor-result", withExtension: "json", subdirectory: "Fixtures")!)
    let service = FixtureIntelligenceService(returning: [scanData, tailorData])
    return TailorView(
        profileStore: profileStore,
        application: application,
        keyStore: InMemoryAPIKeyStore(key: "sk-preview"),
        makeIntelligence: { _ in service }
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
    let review = TailorReview(
        result: result, achievementsByID: ["a1": achievement],
        matchedTagNames: ["Kubernetes"])
    return TailorReviewView(review: review, onCancel: {}, onDone: {})
        .frame(width: 640, height: 480)
}

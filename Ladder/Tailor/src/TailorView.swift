import SwiftUI

/// The tailor flow's sheet: the tailor sheet (company, role title, pasted
/// job description), the run, then the side-by-side review. One view per
/// store phase.
struct TailorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store: TailorStore
    @State private var details = JobDetails(company: "", roleTitle: "", jobDescription: "")
    // The cv-export hand-off: the export happens on "Export CV…" in review,
    // then the save panel, then the fit report (CVExport SPEC.md).
    @State private var exportStore: CVExportStore
    @State private var export: CVExportStore.Export?
    @State private var isSavingPDF = false
    @State private var exportFailed = false

    private let profileStore: ProfileStore

    init(
        profileStore: ProfileStore,
        keyStore: any APIKeyStore = KeychainAPIKeyStore(),
        makeIntelligence: ((String) -> any IntelligenceService)? = nil
    ) {
        self.profileStore = profileStore
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
            case .idle:
                tailorSheet
            case .running:
                progress("Matching your achievements to the job…")
            case .review:
                if let export {
                    FitReportView(report: export.fitReport, onDone: { dismiss() })
                } else if let review = store.review {
                    TailorReviewView(
                        review: review,
                        onCancel: { store.reset() },
                        onDone: { dismiss() },
                        onExport: { runExport(review: review) }
                    )
                }
            case .failed(let error):
                failed(error)
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
            // Declining the save does not undo the persisted Application
            // (CVExport decisions/0003); the fit report shows either way.
        }
        .alert("The CV couldn't be exported.", isPresented: $exportFailed) {
            Button("OK", role: .cancel) {}
        }
    }

    private func runExport(review: TailorReview) {
        guard let profile = profileStore.profile else { return }
        do {
            export = try exportStore.export(profile: profile, review: review, details: details)
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

    private var canRun: Bool {
        !details.jobDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var tailorSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tailor your Profile to a job")
                .font(.title3)
                .foregroundStyle(Color.ink)
            Text("Paste the job description. Ladder selects your best-fit achievements and proposes rewordings — your Profile itself is never changed.")
                .font(.callout)
                .foregroundStyle(Color.inkSoft)

            HStack(spacing: 12) {
                TextField("Company", text: $details.company)
                TextField("Role title", text: $details.roleTitle)
            }
            .textFieldStyle(.roundedBorder)

            Text("Job description")
                .font(.headline)
                .foregroundStyle(Color.ink)
            TextEditor(text: $details.jobDescription)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: 8))
                .frame(minHeight: 160)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Tailor") {
                    let details = details
                    Task { await store.startRun(details) }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.pine)
                .disabled(!canRun)
            }
        }
        .padding(24)
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
                    Button("Try again") { store.reset() }
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
            "Paste the job description first — that's what your achievements are matched against."
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

/// The review (slice CONTEXT.md): each rephrasing beside its achievement's
/// canonical text, accepted by default, with the gaps and the rationale in
/// plain sight.
struct TailorReviewView: View {
    @Bindable var review: TailorReview
    var onCancel: () -> Void
    var onDone: () -> Void
    /// The cv-export hand-off; the review itself never exports.
    var onExport: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            List {
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
                Section("Rephrasings") {
                    ForEach(review.items) { item in
                        ReviewedRephrasingRow(item: item)
                    }
                }
            }
            .scrollContentBackground(.hidden)

            Divider()
            HStack {
                Text("Rejected rewordings fall back to your own words — the canon stays yours.")
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
}

private struct ReviewedRephrasingRow: View {
    @Bindable var item: ReviewedRephrasing

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $item.accepted) {
                Text(item.rephrasing)
                    .font(.body)
                    .foregroundStyle(Color.ink)
            }
            .toggleStyle(.checkbox)

            HStack(alignment: .top, spacing: 4) {
                Text("On file:")
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

#Preview("Tailor sheet") {
    let profileStore = try! ProfileStore(container: ProfileStore.container(inMemory: true))
    try! profileStore.createProfile(name: "Alex Climber", headline: "Staff Engineer")
    let role = try! profileStore.addRole(company: "Acme", title: "Senior Engineer", start: .now, end: nil)
    try! profileStore.addAchievement(to: role, text: "Cut CI build times across every product target")
    return TailorView(
        profileStore: profileStore,
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
          "selections": [
            {"achievementID": "a1", "rephrasing": "Drove CI build times down across every product target"}
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

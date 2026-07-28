import SwiftData
import SwiftUI

/// The caller gates on the job description ([PIPEBOARD-45]).
struct MatchSection: View {
    @State private var model: MatchSectionModel

    init(
        application: Application,
        keyStore: any APIKeyStore = KeychainAPIKeyStore(),
        makeIntelligence: ((String) -> any IntelligenceService)? = nil
    ) {
        if let makeIntelligence {
            _model = State(initialValue: MatchSectionModel(
                application: application, keyStore: keyStore,
                makeIntelligence: makeIntelligence))
        } else {
            _model = State(initialValue: MatchSectionModel(
                application: application, keyStore: keyStore))
        }
    }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                switch model.phase {
                case .scanning:
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Scanning the job description against your tags…")
                            .font(.callout)
                            .foregroundStyle(Color.inkSoft)
                    }
                case .failed(let error):
                    Text(Self.message(for: error))
                        .font(.callout)
                        .foregroundStyle(Color.clay)
                    Button("Try again") {
                        Task { await model.retry() }
                    }
                case .idle, .review:
                    if let summary = model.summary {
                        summaryContent(summary)
                    } else {
                        Text("Scan the job description to see how it matches your tag vocabulary.")
                            .font(.callout)
                            .foregroundStyle(Color.inkSoft)
                    }
                    ForEach(model.confirmationNotes, id: \.self) { note in
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(Color.clay)
                    }
                }
            }
            .padding(.vertical, 2)
            .sheet(isPresented: reviewPresented) {
                if let review = model.matchReview {
                    MatchReviewView(
                        model: review,
                        onCancel: { model.cancelReview() },
                        onContinue: { model.confirmReview() },
                        continueLabel: "Done"
                    )
                    .frame(minWidth: 640, minHeight: 480)
                    .background(Color.paper)
                }
            }
        } header: {
            HStack {
                Text("Match")
                Spacer()
                Button(model.summary == nil ? "Scan JD" : "Re-scan") {
                    Task { await model.scan() }
                }
                .buttonStyle(.borderless)
                .disabled(model.phase == .scanning)
                .help("Scan the job description against your tag vocabulary")
            }
        }
        .listRowBackground(Color.paperRaised)
    }

    private var reviewPresented: Binding<Bool> {
        Binding(
            get: { model.matchReview != nil },
            set: { if !$0 { model.cancelReview() } }
        )
    }

    @ViewBuilder
    private func summaryContent(_ summary: MatchSectionModel.Summary) -> some View {
        if let score = summary.score {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(score)%")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.pine)
                Text("of the job's asks match your tags")
                    .font(.caption)
                    .foregroundStyle(Color.inkSoft)
            }
        } else {
            Text("No vocabulary asks found in this job description.")
                .font(.callout)
                .foregroundStyle(Color.inkSoft)
        }
        if !summary.matchedTagNames.isEmpty {
            Text(summary.matchedTagNames.joined(separator: "  ·  "))
                .font(.caption)
                .foregroundStyle(Color.ink)
        }
        ForEach(summary.vocabularyGaps, id: \.self) { gap in
            Label {
                Text(gap)
                    .font(.caption)
                    .foregroundStyle(Color.ink)
            } icon: {
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(Color.clay)
            }
        }
        Text("Scanned \(summary.scannedAt.formatted(.relative(presentation: .named)))")
            .font(.caption)
            .foregroundStyle(Color.inkSoft)
    }

    private static func message(for error: JDScanError) -> String {
        switch error {
        case .jobDescriptionRequired:
            "This application has no job description yet. Add or import one first."
        case .apiKeyRequired:
            "Scanning needs your Anthropic API key. Add it in Settings — it's stored only in your Keychain."
        case .requestFailed(let detail):
            "The scan couldn't be completed (\(detail)). Check your connection and try again."
        case .responseTruncated:
            "The scan response was cut off before it finished. Try again."
        case .resultInvalid:
            "The scan result didn't come back in a shape Ladder could read, even after one repair. Nothing was changed."
        }
    }
}

#Preview("Match section") {
    let profileStore = try! ProfileStore(container: ProfileStore.container(inMemory: true))
    try! profileStore.createProfile(name: "Alex Climber", headline: "Staff Engineer")
    let role = try! profileStore.addRole(
        company: "Acme", title: "Senior Engineer", start: .now, end: nil)
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
        status: .active)
    context.insert(application)
    try! context.save()
    let scanData = try! Data(
        contentsOf: Bundle.main.url(
            forResource: "jd-scan", withExtension: "json", subdirectory: "Fixtures")!)
    return Form {
        MatchSection(
            application: application,
            keyStore: InMemoryAPIKeyStore(key: "sk-preview"),
            makeIntelligence: { _ in FixtureIntelligenceService(returning: [scanData]) })
    }
    .formStyle(.grouped)
    .scrollContentBackground(.hidden)
    .background(Color.paper)
    .frame(width: 340, height: 400)
}

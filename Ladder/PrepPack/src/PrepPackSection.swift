import SwiftData
import SwiftUI

/// The prep-pack section of the Stage form: Generate sits beside the inputs
/// it draws on, the generated pack renders below, and the whole pack exports
/// as one markdown file. Generation is an explicit user action — the only
/// place the prep API is called.
struct PrepPackSection: View {
    var stage: Stage

    @State private var store: PrepPackStore
    @State private var isSavingMarkdown = false
    private let hasAPIKey: Bool

    init(
        container: ModelContainer,
        stage: Stage,
        keyStore: any APIKeyStore = KeychainAPIKeyStore(),
        makeIntelligence: ((String) -> any IntelligenceService)? = nil
    ) {
        self.stage = stage
        let profileStore = ProfileStore(container: container)
        try? profileStore.load()
        hasAPIKey = ((try? keyStore.readKey()) ?? nil)?.isEmpty == false
        if let makeIntelligence {
            _store = State(initialValue: PrepPackStore(
                container: container, profileStore: profileStore, keyStore: keyStore,
                makeIntelligence: makeIntelligence
            ))
        } else {
            _store = State(initialValue: PrepPackStore(
                container: container, profileStore: profileStore, keyStore: keyStore
            ))
        }
    }

    /// Only all-three-empty leaves nothing to prep from ([PREP-5]).
    private var hasInputs: Bool {
        let jobDescription = stage.application?.jobDescription
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let prepContext = stage.prepContext
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return !jobDescription.isEmpty || !prepContext.isEmpty
            || !PrepPackPayload.priorDebriefs(for: stage).isEmpty
    }

    private var isRunning: Bool { store.phase == .running }

    private var exportFilename: String {
        let company = stage.application?.company ?? ""
        return company.isEmpty ? "Prep pack" : "Prep pack — \(company)"
    }

    var body: some View {
        Section("Prep pack") {
            if let pack = stage.prepPack {
                PrepPackContentView(pack: pack)
                Text("Generating again replaces this prep pack.")
                    .font(.callout)
                    .foregroundStyle(Color.inkSoft)
            } else if !hasInputs {
                Text("Add a job description or prep context — or debrief an earlier stage — and the prep pack draws on them.")
                    .font(.callout)
                    .foregroundStyle(Color.inkSoft)
            } else if !hasAPIKey {
                Text("Add your API key in Settings to generate a prep pack.")
                    .font(.callout)
                    .foregroundStyle(Color.inkSoft)
            } else {
                Text("Prep the call: likely questions, talking points to land, and what earlier debriefs taught.")
                    .font(.callout)
                    .foregroundStyle(Color.inkSoft)
            }
            HStack {
                Button(isRunning ? "Generating…" : (stage.prepPack == nil ? "Generate" : "Regenerate")) {
                    generate()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.pine)
                .disabled(!hasInputs || !hasAPIKey || isRunning)
                if stage.prepPack != nil {
                    Button("Export Markdown…") {
                        isSavingMarkdown = true
                    }
                }
                if case .failed(let error) = store.phase {
                    Text(failureMessage(for: error))
                        .font(.callout)
                        .foregroundStyle(Color.clay)
                }
            }
            .fileExporter(
                isPresented: $isSavingMarkdown,
                document: stage.prepPack.map {
                    MarkdownFileDocument(text: PrepPackMarkdown.render($0, for: stage))
                },
                contentType: MarkdownFileDocument.markdownType,
                defaultFilename: exportFilename
            ) { _ in
                // Declining the save changes nothing — the pack stays on the
                // Stage either way.
            }
        }
    }

    private func generate() {
        Task {
            await store.generate(for: stage, generatedAt: .now)
        }
    }

    private func failureMessage(for error: PrepPackError) -> String {
        switch error {
        case .inputsRequired:
            "There's nothing to prep from yet — add a JD, prep context, or an earlier debrief."
        case .apiKeyRequired:
            "Add your API key in Settings first."
        case .resultInvalid:
            "The service couldn't produce a usable prep pack — try again."
        case .requestFailed:
            "The request failed — check the connection and try again."
        }
    }
}

/// Renders a persisted prep pack: company brief, likely questions, talking
/// points beside the Achievements behind them, and mock tasks.
struct PrepPackContentView: View {
    var pack: PrepPack

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Generated \(pack.generatedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(Color.inkSoft)

            if let brief = pack.companyBrief, !brief.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Company brief")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Color.ink)
                    Text(brief)
                        .font(.callout)
                        .foregroundStyle(Color.ink)
                }
            }

            if !pack.likelyQuestions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Likely questions")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Color.ink)
                    ForEach(pack.likelyQuestions, id: \.self) { question in
                        Text("• \(question)")
                            .font(.callout)
                            .foregroundStyle(Color.ink)
                    }
                }
            }

            let points = pack.orderedTalkingPoints
            if !points.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Talking points")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Color.ink)
                    ForEach(points, id: \.persistentModelID) { point in
                        Text("• \(point.text)")
                            .font(.callout)
                            .foregroundStyle(Color.ink)
                        ForEach(point.achievements, id: \.persistentModelID) { achievement in
                            Label {
                                Text(achievement.text)
                                    .font(.callout)
                                    .foregroundStyle(Color.ink)
                            } icon: {
                                Image(systemName: "bolt.fill")
                                    .foregroundStyle(Color.summitGold)
                            }
                        }
                    }
                }
            }

            if !pack.mockTasks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mock tasks")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Color.ink)
                    ForEach(pack.mockTasks, id: \.self) { task in
                        Text(task.title)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(Color.ink)
                        Text(task.brief)
                            .font(.callout)
                            .foregroundStyle(Color.ink)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let container = try! ProfileStore.container(inMemory: true)
    let context = ModelContext(container)
    let application = Application(
        company: "Summit Labs", roleTitle: "Platform Engineer",
        jobDescription: "Own platform reliability.", status: .active)
    context.insert(application)
    let stage = Stage(kind: .technical, prepContext: "Panel of three; whiteboard likely.")
    context.insert(stage)
    stage.application = application
    let achievement = Achievement(text: "Led incident response for the payments outage")
    context.insert(achievement)
    let pack = PrepPack(
        generatedAt: .now,
        likelyQuestions: [
            "Walk me through a production incident you owned end to end.",
            "How would you scale our ingestion pipeline?",
        ],
        companyBrief: "Summit Labs is hiring a Platform Engineer to own reliability.",
        mockTasks: [
            MockTask(
                title: "Design a rate limiter",
                brief: "Sketch a rate limiter for a multi-tenant API.")
        ])
    context.insert(pack)
    let point = PrepTalkingPoint(
        text: "Lead with the payments-outage incident command story",
        achievements: [achievement])
    context.insert(point)
    point.prepPack = pack
    stage.prepPack = pack
    return Form {
        PrepPackSection(
            container: container, stage: stage,
            keyStore: InMemoryAPIKeyStore(key: "sk-preview"))
    }
    .formStyle(.grouped)
    .frame(width: 460, height: 640)
}

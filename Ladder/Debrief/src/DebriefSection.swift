import SwiftData
import SwiftUI

/// The debrief section of the Stage form: Generate sits beside the notes
/// attach it depends on, and the generated debrief renders below. Generation
/// is an explicit user action — the only place the debrief API is called.
struct DebriefSection: View {
    var stage: Stage

    @State private var store: DebriefStore
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
            _store = State(initialValue: DebriefStore(
                container: container, profileStore: profileStore, keyStore: keyStore,
                makeIntelligence: makeIntelligence
            ))
        } else {
            _store = State(initialValue: DebriefStore(
                container: container, profileStore: profileStore, keyStore: keyStore
            ))
        }
    }

    private var hasNotes: Bool {
        stage.transcript?.notesSummary?
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var isRunning: Bool { store.phase == .running }

    var body: some View {
        Section("Debrief") {
            if let debrief = stage.debrief {
                DebriefContentView(debrief: debrief)
                Text("Generating again replaces this debrief.")
                    .font(.callout)
                    .foregroundStyle(Color.inkSoft)
            } else if !hasNotes {
                Text("Attach the call's Granola notes first — the debrief reads them.")
                    .font(.callout)
                    .foregroundStyle(Color.inkSoft)
            } else if !hasAPIKey {
                Text("Add your API key in Settings to generate a debrief.")
                    .font(.callout)
                    .foregroundStyle(Color.inkSoft)
            } else {
                Text("Debrief the call: questions, answer quality, and the ammo left on the table.")
                    .font(.callout)
                    .foregroundStyle(Color.inkSoft)
            }
            HStack {
                Button(isRunning ? "Generating…" : (stage.debrief == nil ? "Generate" : "Regenerate")) {
                    generate()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.pine)
                .disabled(!hasNotes || !hasAPIKey || isRunning)
                if case .failed(let error) = store.phase {
                    Text(failureMessage(for: error))
                        .font(.callout)
                        .foregroundStyle(Color.clay)
                }
            }
        }
    }

    private func generate() {
        Task {
            await store.generate(for: stage, generatedAt: .now)
        }
    }

    private func failureMessage(for error: DebriefError) -> String {
        switch error {
        case .notesRequired:
            "There are no notes to ground a debrief in — attach them first."
        case .apiKeyRequired:
            "Add your API key in Settings first."
        case .resultInvalid:
            "The service couldn't produce a grounded debrief — try again."
        case .requestFailed:
            "The request failed — check the connection and try again."
        }
    }
}

/// Renders a persisted debrief: question entries with quality and missed
/// ammo, then themes, signals, and drills — every claim beside its quote.
struct DebriefContentView: View {
    var debrief: Debrief

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Generated \(debrief.generatedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(Color.inkSoft)

            ForEach(debrief.orderedQuestions, id: \.persistentModelID) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(entry.question)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(Color.ink)
                        Spacer()
                        qualityBadge(entry.quality)
                    }
                    Text(entry.answerSummary)
                        .font(.callout)
                        .foregroundStyle(Color.ink)
                    quote(entry.quote)
                    if !entry.missedAmmo.isEmpty {
                        ForEach(entry.missedAmmo, id: \.persistentModelID) { achievement in
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

            remarks("Themes", debrief.themes)
            remarks("Signals", debrief.signals)
            if !debrief.drills.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Drills")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Color.ink)
                    ForEach(debrief.drills, id: \.self) { drill in
                        Text("• \(drill)")
                            .font(.callout)
                            .foregroundStyle(Color.ink)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func remarks(_ title: String, _ items: [GroundedRemark]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.ink)
                ForEach(items, id: \.self) { remark in
                    Text(remark.text)
                        .font(.callout)
                        .foregroundStyle(Color.ink)
                    quote(remark.quote)
                }
            }
        }
    }

    private func quote(_ text: String) -> some View {
        Text("“\(text)”")
            .font(.callout.italic())
            .foregroundStyle(Color.inkSoft)
    }

    private func qualityBadge(_ quality: AnswerQuality) -> some View {
        Text(quality.rawValue)
            .font(.caption.weight(.semibold))
            .foregroundStyle(badgeColor(quality))
    }

    private func badgeColor(_ quality: AnswerQuality) -> Color {
        switch quality {
        case .strong: .pine
        case .adequate: .summitGold
        case .weak: .clay
        }
    }
}

#Preview {
    let container = try! ProfileStore.container(inMemory: true)
    let context = ModelContext(container)
    let stage = Stage(kind: .technical)
    context.insert(stage)
    let transcript = Transcript(
        recordedAt: .now,
        notesSummary: "## Payments outage\n- Walked through the incident timeline")
    context.insert(transcript)
    stage.transcript = transcript
    let debrief = Debrief(
        generatedAt: .now,
        themes: [GroundedRemark(
            text: "Reliability ran through the whole conversation",
            quote: "Walked through the incident timeline")],
        signals: [GroundedRemark(
            text: "The interviewer probed Kubernetes depth twice",
            quote: "Walked through the incident timeline")],
        drills: ["Rehearse the outage story leading with the incident-command role"]
    )
    context.insert(debrief)
    let question = DebriefQuestion(
        question: "How did you handle the payments outage?",
        answerSummary: "Walked the timeline but never claimed the lead",
        quality: .adequate,
        quote: "Walked through the incident timeline")
    context.insert(question)
    question.debrief = debrief
    stage.debrief = debrief
    return Form {
        DebriefSection(
            container: container, stage: stage,
            keyStore: InMemoryAPIKeyStore(key: "sk-preview"))
    }
    .formStyle(.grouped)
    .frame(width: 460, height: 600)
}

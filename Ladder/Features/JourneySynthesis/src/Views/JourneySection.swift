import SwiftData
import SwiftUI

struct JourneySection: View {
    var application: Application

    @State private var store: JourneyStore
    @State private var isConfirmingRemoval = false
    @State private var removeFailed = false
    private let hasAPIKey: Bool

    init(
        container: ModelContainer,
        application: Application,
        keyStore: any APIKeyStore = KeychainAPIKeyStore(),
        makeIntelligence: ((String) -> any IntelligenceService)? = nil
    ) {
        self.application = application
        hasAPIKey = ((try? keyStore.readKey()) ?? nil)?.isEmpty == false
        if let makeIntelligence {
            _store = State(initialValue: JourneyStore(
                container: container, keyStore: keyStore,
                makeIntelligence: makeIntelligence
            ))
        } else {
            _store = State(initialValue: JourneyStore(
                container: container, keyStore: keyStore
            ))
        }
    }

    static func appears(status: ApplicationStatus, hasNarrative: Bool) -> Bool {
        hasNarrative || status == .offer
    }

    static func showsGenerate(for status: ApplicationStatus) -> Bool {
        status == .offer
    }

    private var isRunning: Bool { store.phase == .running }

    var body: some View {
        if Self.appears(
            status: application.status,
            hasNarrative: application.journeyNarrative != nil)
        {
            Section("Journey") {
                if let narrative = application.journeyNarrative {
                    Text(narrative.text)
                        .font(.callout)
                        .foregroundStyle(Color.ink)
                        .textSelection(.enabled)
                    HStack {
                        Text("Generated \(narrative.generatedAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(Color.inkSoft)
                        Spacer()
                        Button("Remove", role: .destructive) {
                            isConfirmingRemoval = true
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                    .confirmationDialog(
                        "Remove this journey narrative?",
                        isPresented: $isConfirmingRemoval
                    ) {
                        Button("Remove", role: .destructive) { remove() }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Generating it again takes another API call.")
                    }
                    if removeFailed {
                        Text("Removing the narrative failed.")
                            .font(.callout)
                            .foregroundStyle(Color.clay)
                    }
                } else if !hasAPIKey {
                    Text("Add your API key in Settings to tell this journey's story.")
                        .font(.callout)
                        .foregroundStyle(Color.inkSoft)
                } else {
                    Text("The offer is in — tell the story of the climb, from application to summit.")
                        .font(.callout)
                        .foregroundStyle(Color.inkSoft)
                }
                if Self.showsGenerate(for: application.status) {
                    HStack {
                        Button(
                            isRunning
                                ? "Generating…"
                                : (application.journeyNarrative == nil
                                    ? "Generate" : "Regenerate")
                        ) {
                            generate()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.pine)
                        .disabled(!hasAPIKey || isRunning)
                        if case .failed(let error) = store.phase {
                            Text(failureMessage(for: error))
                                .font(.callout)
                                .foregroundStyle(Color.clay)
                        }
                    }
                }
            }
            .listRowBackground(Color.paperRaised)
        }
    }

    private func generate() {
        Task {
            await store.generate(for: application, generatedAt: .now)
        }
    }

    private func remove() {
        do {
            try store.removeNarrative(from: application)
            removeFailed = false
        } catch {
            removeFailed = true
        }
    }

    private func failureMessage(for error: JourneyError) -> String {
        switch error {
        case .offerRequired:
            "The journey narrative arrives with the offer."
        case .apiKeyRequired:
            "Add your API key in Settings first."
        case .resultInvalid:
            "The service couldn't produce a usable narrative — try again."
        case .requestFailed:
            "The request failed — check the connection and try again."
        }
    }
}

#Preview {
    let container = try! ProfileStore.container(inMemory: true)
    let context = ModelContext(container)
    let application = Application(
        company: "Summit Labs", roleTitle: "Platform Engineer",
        jobDescription: "Own platform reliability.", status: .offer,
        appliedAt: .now.addingTimeInterval(-41 * 86_400))
    context.insert(application)
    let narrative = JourneyNarrative(
        text: "The Summit Labs climb opened quietly: an application sent on a Tuesday, a referral doing the early carrying.\n\nForty-one days after base camp, the offer arrived — not a lucky summit, a climbed one.",
        generatedAt: .now)
    context.insert(narrative)
    application.journeyNarrative = narrative
    return Form {
        JourneySection(
            container: container, application: application,
            keyStore: InMemoryAPIKeyStore(key: "sk-preview"))
    }
    .formStyle(.grouped)
    .frame(width: 460, height: 420)
}

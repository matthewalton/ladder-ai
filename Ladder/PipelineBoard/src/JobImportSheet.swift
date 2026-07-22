import SwiftUI
import UniformTypeIdentifiers

/// The board's one creation door ([PIPEBOARD-41]): a posting link or PDF
/// in, a draft Application out — no typing.
struct JobImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store: JobImportStore
    @State private var linkText = ""
    @State private var isPickingFile = false
    @State private var showsLinkError = false

    private let onCreated: (Application) -> Void

    init(
        pipelineStore: PipelineStore,
        keyStore: any APIKeyStore = KeychainAPIKeyStore(),
        makeIntelligence: ((String) -> any IntelligenceService)? = nil,
        onCreated: @escaping (Application) -> Void = { _ in }
    ) {
        if let makeIntelligence {
            _store = State(initialValue: JobImportStore(
                pipelineStore: pipelineStore, keyStore: keyStore,
                makeIntelligence: makeIntelligence
            ))
        } else {
            _store = State(initialValue: JobImportStore(
                pipelineStore: pipelineStore, keyStore: keyStore
            ))
        }
        self.onCreated = onCreated
    }

    var body: some View {
        Group {
            switch store.phase {
            case .idle:
                inputSurface
            case .running, .created:
                // `.created` shows the same progress for the instant before
                // the sheet dismisses.
                progress
            case .failed(let error):
                failed(error)
            }
        }
        .frame(minWidth: 520, minHeight: 400)
        .background(Color.paper)
        .onChange(of: store.phase) { _, phase in
            if case .created(let application) = phase {
                onCreated(application)
                dismiss()
            }
        }
        .fileImporter(
            isPresented: $isPickingFile,
            allowedContentTypes: [.pdf]
        ) { result in
            guard case .success(let url) = result else { return }
            importFile(url)
        }
    }

    /// http(s) only, refused before any store call ([PIPEBOARD-38]).
    static func postingURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme?.hasPrefix("http") == true else {
            return nil
        }
        return url
    }

    private var inputSurface: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create a CV for a new application")
                .font(.title3)
                .foregroundStyle(Color.ink)
            Text("Paste the job posting's link, or drop its PDF. Ladder reads the posting, files the application, and you review the CV it tailors — no typing.")
                .font(.callout)
                .foregroundStyle(Color.inkSoft)

            HStack(spacing: 8) {
                TextField("https://…", text: $linkText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(submitLink)
                Button("Import") { submitLink() }
                    .disabled(linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if showsLinkError {
                Text("That link isn't a valid URL.")
                    .font(.callout)
                    .foregroundStyle(Color.clay)
            }

            VStack(spacing: 8) {
                Image(systemName: "arrow.down.doc")
                    .font(.title2)
                    .foregroundStyle(Color.inkSoft)
                Text("Drop the posting's PDF here")
                    .font(.callout)
                    .foregroundStyle(Color.inkSoft)
                Button("Choose PDF…") { isPickingFile = true }
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        Color.inkSoft.opacity(0.4),
                        style: StrokeStyle(lineWidth: 1, dash: [5])
                    )
            )
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first else { return false }
                importFile(url)
                return true
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
            }
        }
        .padding(24)
    }

    private var progress: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Reading the posting…")
                .font(.callout)
                .foregroundStyle(Color.inkSoft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failed(_ error: JobImportError) -> some View {
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

    private func message(for error: JobImportError) -> String {
        switch error {
        case .fetchFailed:
            "The link couldn't be fetched. If the posting sits behind a login, save it as a PDF and drop that instead."
        case .noExtractableText:
            "No text could be extracted from that posting."
        case .apiKeyRequired:
            "Importing a posting needs your Anthropic API key. Add it in Settings — it's stored only in your Keychain."
        case .resultInvalid:
            "The posting couldn't be read into job details, even after one repair. Nothing was created."
        case .requestFailed:
            "The request couldn't be completed. Check your connection and try again."
        }
    }

    private func submitLink() {
        guard let url = Self.postingURL(from: linkText) else {
            showsLinkError = true
            return
        }
        showsLinkError = false
        Task { await store.importPosting(fromLink: url) }
    }

    private func importFile(_ url: URL) {
        Task {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            await store.importPosting(fromFile: url)
        }
    }
}

#Preview {
    let store = try! PipelineStore(container: ProfileStore.container(inMemory: true))
    return JobImportSheet(
        pipelineStore: store,
        keyStore: InMemoryAPIKeyStore(key: "sk-preview"),
        makeIntelligence: { _ in FixtureIntelligenceService.jobDetailsFixture() }
    )
}

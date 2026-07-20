import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// The transcript section of the Stage form sheet (decisions/0004): the
/// readout when a transcript is attached, the import entry either way, and
/// the .txt/.md drop target.
struct TranscriptSectionView: View {
    var container: ModelContainer
    var stage: Stage

    private struct ImportRequest: Identifiable {
        let id = UUID()
        var initialText: String
    }

    // Non-optional from init: the sheet's content closure reads this, and an
    // optional set in the same transaction as the presentation reads stale
    // nil on first present — an empty sheet.
    @State private var importStore: TranscriptImportStore
    @State private var importRequest: ImportRequest?
    @State private var dropFailed = false

    init(container: ModelContainer, stage: Stage) {
        self.container = container
        self.stage = stage
        _importStore = State(initialValue: TranscriptImportStore(container: container))
    }

    var body: some View {
        Section("Transcript") {
            if let transcript = stage.transcript {
                TranscriptReadoutView(transcript: transcript)
                Button("Replace Transcript…") { openImport() }
            } else {
                Text("Paste the Granola transcript, or drop it as a .txt or .md file.")
                    .font(.callout)
                    .foregroundStyle(Color.inkSoft)
                Button("Import Transcript…") { openImport() }
            }
            if dropFailed {
                Text("Only .txt or .md files can be imported.")
                    .font(.callout)
                    .foregroundStyle(Color.clay)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            handleDrop(of: urls)
        }
        .sheet(item: $importRequest) { request in
            TranscriptImportSheet(
                store: importStore, stage: stage, initialText: request.initialText)
        }
    }

    private func openImport(withText text: String = "") {
        importRequest = ImportRequest(initialText: text)
    }

    private func handleDrop(of urls: [URL]) -> Bool {
        guard let url = urls.first else { return false }
        dropFailed = false
        let ext = url.pathExtension.lowercased()
        guard TranscriptImportStore.importableExtensions.contains(ext),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            dropFailed = true
            return false
        }
        openImport(withText: text)
        return true
    }
}

#Preview {
    let container = try! ProfileStore.container(inMemory: true)
    let stage = Stage(kind: .technical)
    ModelContext(container).insert(stage)
    return Form {
        TranscriptSectionView(container: container, stage: stage)
    }
    .formStyle(.grouped)
    .frame(width: 460)
}

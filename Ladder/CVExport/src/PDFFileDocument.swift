import SwiftUI
import UniformTypeIdentifiers

/// The save panel's document (decisions/0003): a thin wrapper around the
/// export's PDF bytes. It never re-renders — the bytes it writes are the
/// bytes on the Application's snapshot ([CVEXPORT-12]).
struct PDFFileDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.pdf]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = contents
    }

    /// The write seam, testable without a `WriteConfiguration` (which has no
    /// public initializer).
    func fileWrapper() -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        fileWrapper()
    }
}

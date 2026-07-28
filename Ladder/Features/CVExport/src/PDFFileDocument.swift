import SwiftUI
import UniformTypeIdentifiers

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

import SwiftUI
import UniformTypeIdentifiers

struct MarkdownFileDocument: FileDocument {
    static let markdownType: UTType =
        UTType(filenameExtension: "md", conformingTo: .plainText) ?? .plainText
    static let readableContentTypes: [UTType] = [markdownType]

    let text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = String(decoding: contents, as: UTF8.self)
    }

    /// The write seam, testable without a `WriteConfiguration` (which has no
    /// public initializer).
    func fileWrapper() -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        fileWrapper()
    }
}

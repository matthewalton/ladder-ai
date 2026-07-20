import SwiftUI
import UniformTypeIdentifiers

/// A thin wrapper around the export's markdown text — rendering happened
/// before the save panel opened; the bytes written are the rendered string.
struct MarkdownFileDocument: FileDocument {
    /// `.md` resolves to the system's markdown type where one is declared;
    /// plain text is the honest fallback.
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

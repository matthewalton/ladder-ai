import AppKit
import Foundation
import PDFKit

enum TextExtractionError: Error, Equatable {
    case unsupportedFileType
    /// Covers a file that fails to open and one that opens to no text —
    /// an image-only PDF extracts an empty string.
    case noExtractableText
}

/// File on disk → plain text, entirely on-device; what the text means is the
/// caller's business. Shared by cv-import and the pipeline-board JD import
/// (PipelineBoard decisions/0005).
@MainActor
enum FileTextExtractor {
    static func extractText(from url: URL) throws -> String {
        let text: String
        switch url.pathExtension.lowercased() {
        case "pdf":
            guard let document = PDFDocument(url: url) else {
                throw TextExtractionError.noExtractableText
            }
            text = document.string ?? ""
        case "docx":
            guard let attributed = try? NSAttributedString(
                url: url,
                options: [.documentType: NSAttributedString.DocumentType.officeOpenXML],
                documentAttributes: nil
            ) else {
                throw TextExtractionError.noExtractableText
            }
            text = attributed.string
        default:
            throw TextExtractionError.unsupportedFileType
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TextExtractionError.noExtractableText
        }
        return text
    }
}

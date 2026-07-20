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

    /// Fetched link bytes → plain text, for the pipeline-board JD link
    /// import (PipelineBoard decisions/0006). A PDF payload (`%PDF` magic)
    /// extracts via PDFKit — without the sniff the HTML importer renders
    /// the raw bytes as garbage text. Anything else reads as HTML; the
    /// importer sniffs the document's own charset.
    static func extractText(fromFetchedData data: Data) throws -> String {
        let text: String
        if data.starts(with: Array("%PDF".utf8)) {
            guard let document = PDFDocument(data: data) else {
                throw TextExtractionError.noExtractableText
            }
            text = document.string ?? ""
        } else {
            guard let attributed = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.html],
                documentAttributes: nil
            ) else {
                throw TextExtractionError.noExtractableText
            }
            text = attributed.string
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TextExtractionError.noExtractableText
        }
        return text
    }
}

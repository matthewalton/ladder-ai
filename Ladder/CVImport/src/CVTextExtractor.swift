import AppKit
import Foundation
import PDFKit

/// Extraction (slice CONTEXT.md): dropped file → plain text, entirely
/// on-device. PDFKit for PDF; AttributedString's Office Open XML reading for
/// docx. Extraction produces text; structuring it is the service's job.
@MainActor
enum CVTextExtractor {
    static func extractText(from url: URL) throws -> String {
        let text: String
        // File type is judged before extraction is attempted ([CVIMPORT-12]).
        switch url.pathExtension.lowercased() {
        case "pdf":
            guard let document = PDFDocument(url: url) else {
                throw ImportError.extractionFailed
            }
            text = document.string ?? ""
        case "docx":
            guard let attributed = try? NSAttributedString(
                url: url,
                options: [.documentType: NSAttributedString.DocumentType.officeOpenXML],
                documentAttributes: nil
            ) else {
                throw ImportError.extractionFailed
            }
            text = attributed.string
        default:
            throw ImportError.unsupportedFileType
        }
        // An image-only or empty CV extracts nothing ([CVIMPORT-11]).
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ImportError.extractionFailed
        }
        return text
    }
}

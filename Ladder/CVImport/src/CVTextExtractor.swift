import AppKit
import Foundation
import PDFKit

/// Dropped file → plain text, entirely on-device; structuring the text is
/// the service's job.
@MainActor
enum CVTextExtractor {
    static func extractText(from url: URL) throws -> String {
        let text: String
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
        // An image-only PDF extracts an empty string.
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ImportError.extractionFailed
        }
        return text
    }
}

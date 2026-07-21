import Foundation
import PDFKit

/// Deterministic contact detection (decisions/0009): `NSDataDetector` over
/// the extracted CV text plus the PDF's link annotations. Detected values
/// override the model's proposal ([CVIMPORT-29]); detection fills, never
/// blanks ([CVIMPORT-30]). Location is never detected.
struct DetectedContact: Equatable, Sendable {
    var email: String?
    var phone: String?
    var link: String?

    /// First match per field wins — a CV header leads with the owner's own
    /// details. Email and phone are detected anywhere in the text; a URL
    /// counts as the personal link only when it sits in the header region,
    /// so a per-project link further down never masquerades as the
    /// portfolio URL (the same carve-out the prompt gives the model).
    static func detect(in text: String, fileURL: URL? = nil) -> DetectedContact {
        var detected = DetectedContact()
        let types: NSTextCheckingResult.CheckingType = [.link, .phoneNumber]
        if let detector = try? NSDataDetector(types: types.rawValue) {
            let headerEnd = headerRegionEnd(of: text)
            let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                switch match.resultType {
                case .phoneNumber:
                    if detected.phone == nil { detected.phone = match.phoneNumber }
                case .link:
                    guard let url = match.url else { break }
                    if url.scheme == "mailto" {
                        if detected.email == nil {
                            detected.email = String(url.absoluteString.dropFirst("mailto:".count))
                        }
                    } else if detected.link == nil,
                              let matchRange = Range(match.range, in: text),
                              matchRange.lowerBound < headerEnd {
                        detected.link = url.absoluteString
                    }
                default:
                    break
                }
            }
        }
        if let fileURL {
            detected.absorb(annotationsOf: fileURL)
        }
        return detected
    }

    /// Fills each still-empty field from the PDF's link annotations — URLs
    /// (and mailto/tel) that a template renders as icons never reach the
    /// text layer.
    private mutating func absorb(annotationsOf fileURL: URL) {
        guard let document = PDFDocument(url: fileURL) else { return }
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            for annotation in page.annotations {
                guard let url = annotation.url else { continue }
                switch url.scheme {
                case "mailto":
                    if email == nil { email = String(url.absoluteString.dropFirst("mailto:".count)) }
                case "tel":
                    if phone == nil { phone = String(url.absoluteString.dropFirst("tel:".count)) }
                default:
                    if link == nil { link = url.absoluteString }
                }
            }
        }
    }

    /// The header region: the first five lines. CV headers put the owner's
    /// contact up top; below it, URLs belong to projects and employers.
    private static func headerRegionEnd(of text: String) -> String.Index {
        var end = text.startIndex
        var lines = 0
        while end < text.endIndex, lines < 5 {
            if text[end] == "\n" { lines += 1 }
            end = text.index(after: end)
        }
        return end
    }

    /// Detection fills, never blanks: each detected value replaces the
    /// model's; an undetected field keeps the proposal's value, and
    /// location always passes through untouched.
    func overriding(_ contact: ProposedContact) -> ProposedContact {
        ProposedContact(
            email: email ?? contact.email,
            phone: phone ?? contact.phone,
            location: contact.location,
            link: link ?? contact.link
        )
    }
}

import Foundation
import PDFKit

struct DetectedContact: Equatable, Sendable {
    var email: String?
    var phone: String?
    var link: String?

    /// A URL counts as the personal link only when it sits in the header
    /// region — the same carve-out the prompt gives the model.
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

    /// URLs (and mailto/tel) that a template renders as icons never reach
    /// the text layer.
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

    private static func headerRegionEnd(of text: String) -> String.Index {
        var end = text.startIndex
        var lines = 0
        while end < text.endIndex, lines < 5 {
            if text[end] == "\n" { lines += 1 }
            end = text.index(after: end)
        }
        return end
    }

    func overriding(_ contact: ProposedContact) -> ProposedContact {
        ProposedContact(
            email: email ?? contact.email,
            phone: phone ?? contact.phone,
            location: contact.location,
            link: link ?? contact.link
        )
    }
}

import SwiftUI

/// Renders a `CVDocument` to PDF bytes with `ImageRenderer` (ARCHITECTURE.md
/// tech stack; Typst is a later, separately-decided upgrade). A4 pages
/// ([CVEXPORT-7]), real extractable text — never a rasterised image.
@MainActor
enum CVRenderer {
    /// A4 in PostScript points.
    static let pageSize = CGSize(width: 595.2, height: 841.8)

    static func pdfData(for document: CVDocument) -> Data {
        // The page view is forced light so the print document keeps its
        // paper-and-ink palette regardless of the app's appearance.
        let content = CVPageView(document: document)
            .frame(width: pageSize.width)
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(width: pageSize.width, height: nil)

        let data = NSMutableData()
        renderer.render { size, renderView in
            var mediaBox = CGRect(origin: .zero, size: pageSize)
            guard
                let consumer = CGDataConsumer(data: data as CFMutableData),
                let pdf = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
            else { return }
            // One tall view, sliced into A4 pages: page i shows the content
            // band [height - (i+1)·pageH, height - i·pageH], translated into
            // the media box. Short content stays top-aligned.
            let pageCount = max(1, Int(ceil(size.height / pageSize.height)))
            for page in 0..<pageCount {
                pdf.beginPDFPage(nil)
                pdf.translateBy(x: 0, y: -(size.height - pageSize.height * CGFloat(page + 1)))
                renderView(pdf)
                pdf.endPDFPage()
            }
            pdf.closePDF()
        }
        return data as Data
    }
}

/// The CV's single-column layout (decisions/0002). System text styles only —
/// UI chrome rules apply to the print document too (CLAUDE.md).
struct CVPageView: View {
    var document: CVDocument

    private let margin: CGFloat = 48

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Identity header ([CVEXPORT-2])
            Text(document.name)
                .font(.title)
                .bold()
            Text(document.headline)
                .font(.headline)
            if !document.contactLines.isEmpty {
                Text(document.contactLines.joined(separator: "  ·  "))
                    .font(.caption)
                    .foregroundStyle(Color.inkSoft)
            }

            Divider()

            // Every role, newest-first ([CVEXPORT-3]); selected achievements
            // only, in reviewed text ([CVEXPORT-4], [CVEXPORT-5]).
            ForEach(Array(document.roles.enumerated()), id: \.offset) { _, role in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(role.title), \(role.company)")
                            .font(.headline)
                        Spacer()
                        Text(CVDocument.dateRange(start: role.start, end: role.end))
                            .font(.caption)
                            .foregroundStyle(Color.inkSoft)
                    }
                    ForEach(Array(role.bullets.enumerated()), id: \.offset) { _, bullet in
                        Text("•  \(bullet)")
                            .font(.body)
                    }
                }
            }

            // Skills section ([CVEXPORT-6])
            if !document.skills.isEmpty {
                Divider()
                Text("Skills")
                    .font(.headline)
                Text(document.skills.joined(separator: ", "))
                    .font(.body)
            }
        }
        .foregroundStyle(Color.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(margin)
        .background(Color.white)
    }
}

#Preview {
    CVPageView(document: CVDocument.previewDocument)
        .frame(width: CVRenderer.pageSize.width)
}

extension CVDocument {
    /// Preview-only sample; tests build real documents from a Profile.
    static var previewDocument: CVDocument {
        var document = CVDocument()
        document.name = "Alex Climber"
        document.headline = "Staff Engineer"
        document.contactLines = ["alex@example.com", "London"]
        document.roles = [
            RoleSection(
                title: "Senior Engineer", company: "Acme",
                start: Date(timeIntervalSince1970: 1_600_000_000), end: nil,
                bullets: ["Drove CI build times down across every product target"]
            )
        ]
        document.skills = ["CI/CD", "Swift"]
        return document
    }

    private init() {
        name = ""
        headline = ""
        contactLines = []
        roles = []
        skills = []
    }
}

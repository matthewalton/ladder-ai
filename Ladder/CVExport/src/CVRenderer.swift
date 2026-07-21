import SwiftUI

/// Renders a `CVDocument` to A4 PDF bytes — real extractable text, never a
/// rasterised image.
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

/// System text styles only — the UI chrome rules apply to the print document
/// too.
struct CVPageView: View {
    var document: CVDocument

    private let margin: CGFloat = 48

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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

            if !document.projects.isEmpty {
                Divider()
                Text("Projects")
                    .font(.headline)
                ForEach(Array(document.projects.enumerated()), id: \.offset) { _, project in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(project.name)
                                .font(.headline)
                            if !project.link.isEmpty {
                                Text(project.link)
                                    .font(.caption)
                                    .foregroundStyle(Color.inkSoft)
                            }
                        }
                        ForEach(Array(project.bullets.enumerated()), id: \.offset) { _, bullet in
                            Text("•  \(bullet)")
                                .font(.body)
                        }
                    }
                }
            }

            if !document.education.isEmpty {
                Divider()
                Text("Education")
                    .font(.headline)
                ForEach(Array(document.education.enumerated()), id: \.offset) { _, entry in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(entry.qualification), \(entry.institution)")
                                .font(.body)
                                .bold()
                            Spacer()
                            Text(CVDocument.dateRange(start: entry.start, end: entry.end))
                                .font(.caption)
                                .foregroundStyle(Color.inkSoft)
                        }
                        if !entry.detail.isEmpty {
                            Text(entry.detail)
                                .font(.caption)
                                .foregroundStyle(Color.inkSoft)
                        }
                    }
                }
            }

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
        document.projects = [
            ProjectSection(
                name: "Trail Mapper", link: "github.com/alex/trail-mapper",
                bullets: ["Engineered offline tile caching for a production mapping app"]
            )
        ]
        document.education = [
            EducationSection(
                institution: "University of Example", qualification: "BSc Computer Science",
                start: Date(timeIntervalSince1970: 1_100_000_000),
                end: Date(timeIntervalSince1970: 1_200_000_000),
                detail: "First-class honours"
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
        projects = []
        education = []
        skills = []
    }
}

import SwiftUI

/// Renders a `CVDocument` to A4 PDF bytes — real extractable text, never a
/// rasterised image. Set in the CV template's bundled faces and print
/// palette (`CVTheme`, decisions/0007).
@MainActor
enum CVRenderer {
    /// A4 in PostScript points.
    static let pageSize = CVMetrics.pageSize

    static func pdfData(for document: CVDocument, metrics: CVMetrics = CVMetrics()) -> Data {
        CVTheme.registerFonts()
        let layout = CVLayout(document: document, metrics: metrics)

        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard
            let consumer = CGDataConsumer(data: data as CFMutableData),
            let pdf = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else { return data as Data }

        // One rendered view per page — a page holds whole blocks only
        // ([CVEXPORT-24]), so no text line can straddle the boundary.
        for page in layout.pages {
            // Forced light so the print document keeps its paper-and-ink
            // palette regardless of the app's appearance.
            let content = CVPageView(document: document, blocks: page, metrics: metrics)
                .environment(\.colorScheme, .light)
            let renderer = ImageRenderer(content: content)
            renderer.proposedSize = ProposedViewSize(pageSize)
            pdf.beginPDFPage(nil)
            renderer.render { _, renderView in
                renderView(pdf)
            }
            pdf.endPDFPage()
        }
        pdf.closePDF()
        return data as Data
    }
}

/// One A4 page of the CV template (decisions/0007): caps section headers
/// over hairline rules, company in blue, right-aligned meta dates.
/// Renders exactly the blocks its page was assigned ([CVEXPORT-24]);
/// everything is set in the bundled faces — no system fonts anywhere
/// ([CVEXPORT-34]).
struct CVPageView: View {
    var document: CVDocument
    var blocks: [CVBlock]
    var metrics = CVMetrics()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                blockView(block)
                    .padding(.top, index == 0 ? 0 : block.gapAbove)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CVMetrics.margin)
        .frame(
            width: CVMetrics.pageSize.width,
            height: CVMetrics.pageSize.height,
            alignment: .topLeading
        )
        .background(Color.white)
    }

    @ViewBuilder
    private func blockView(_ block: CVBlock) -> some View {
        switch block.kind {
        case .identityHeader:
            identityHeader
        case .summary:
            Text(document.summary)
                .font(CVTheme.body())
                .foregroundStyle(CVTheme.ink)
        case .sectionHeader(let title):
            sectionHeader(title)
        case .roleHeader(let role):
            roleHeader(document.roles[role])
        case .bullet(let role, let bullet):
            bulletText(document.roles[role].bullets[bullet])
        case .project(let index):
            projectSection(document.projects[index])
        case .education(let index):
            educationSection(document.education[index])
        case .skillsTable:
            skillsTable
        case .interests:
            Text(document.interests.joined(separator: " · "))
                .font(CVTheme.body())
                .foregroundStyle(CVTheme.ink)
        }
    }

    private var identityHeader: some View {
        VStack(alignment: .leading, spacing: metrics.lineGap) {
            Text(document.name)
                .font(CVTheme.name())
                .foregroundStyle(CVTheme.heading)
            if !document.headline.isEmpty {
                Text(document.headline)
                    .font(CVTheme.medium(CVTheme.headlineSize))
                    .foregroundStyle(CVTheme.ink)
            }
            if !document.contactLines.isEmpty {
                Text(document.contactLines.joined(separator: "  ·  "))
                    .font(CVTheme.body(CVTheme.metaSize))
                    .foregroundStyle(CVTheme.meta)
            }
            // The thick header rule.
            Rectangle()
                .fill(CVTheme.heading)
                .frame(height: 2)
                .padding(.top, metrics.lineGap)
        }
    }

    /// Tracked caps over a hairline rule — the reference CV's section
    /// treatment.
    private func sectionHeader(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: metrics.lineGap) {
            // No .tracking(): letter-spacing garbles PDF text extraction
            // ("E X P E R I E N C E"), and the extracted layer is the
            // ATS-parseable guarantee. The tracked look is visual-only debt.
            Text(title)
                .font(CVTheme.semibold(CVTheme.sectionHeaderSize))
                .foregroundStyle(CVTheme.heading)
            Rectangle()
                .fill(CVTheme.hairline)
                .frame(height: 1)
        }
    }

    /// The role line + optional subline — bullets are separate blocks so a
    /// page break can fall between them ([CVEXPORT-24]).
    private func roleHeader(_ role: CVDocument.RoleSection) -> some View {
        VStack(alignment: .leading, spacing: metrics.lineGap) {
            HStack(alignment: .firstTextBaseline) {
                (Text("\(role.title), ")
                    .font(CVTheme.semibold(CVTheme.roleTitleSize))
                    .foregroundStyle(CVTheme.ink)
                    + Text(role.company)
                    .font(CVTheme.semibold(CVTheme.roleTitleSize))
                    .foregroundStyle(CVTheme.heading))
                Spacer()
                Text(CVDocument.dateRange(start: role.start, end: role.end))
                    .font(CVTheme.body(CVTheme.metaSize))
                    .foregroundStyle(CVTheme.meta)
            }
            if let subline = role.subline {
                Text(subline)
                    .font(CVTheme.body(CVTheme.metaSize))
                    .foregroundStyle(CVTheme.meta)
            }
        }
    }

    /// "• **Title** - text" for a titled bullet, "• text" for a plain one
    /// ([CVEXPORT-32]). One concatenated Text so extraction reads the
    /// bullet as a single run.
    private func bulletText(_ bullet: CVDocument.Bullet) -> Text {
        let body = Text(bullet.text)
            .font(CVTheme.body())
            .foregroundStyle(CVTheme.ink)
        let marker = Text("•  ")
            .font(CVTheme.body())
            .foregroundStyle(CVTheme.ink)
        guard let title = bullet.title else { return marker + body }
        let lead = Text("\(title) - ")
            .font(CVTheme.semibold())
            .foregroundStyle(CVTheme.ink)
        return marker + lead + body
    }

    private func projectSection(_ project: CVDocument.ProjectSection) -> some View {
        VStack(alignment: .leading, spacing: metrics.lineGap) {
            HStack(alignment: .firstTextBaseline) {
                Text(project.name)
                    .font(CVTheme.semibold(CVTheme.roleTitleSize))
                    .foregroundStyle(CVTheme.ink)
                Spacer()
                if !project.link.isEmpty {
                    Text(project.link)
                        .font(CVTheme.body(CVTheme.metaSize))
                        .foregroundStyle(CVTheme.meta)
                }
            }
            if !project.details.isEmpty {
                Text(project.details)
                    .font(CVTheme.body())
                    .foregroundStyle(CVTheme.ink)
            }
        }
    }

    /// The two-column categorised table ([CVEXPORT-23]): each cell one
    /// category, name in template blue, its skills after it — one
    /// concatenated Text per cell so extraction reads the pair together.
    private var skillsTable: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), alignment: .topLeading),
                GridItem(.flexible(), alignment: .topLeading),
            ],
            alignment: .leading,
            spacing: metrics.lineGap
        ) {
            ForEach(Array(document.skillCategories.enumerated()), id: \.offset) { _, category in
                (Text("\(category.name): ")
                    .font(CVTheme.semibold())
                    .foregroundStyle(CVTheme.heading)
                    + Text(category.skills.joined(separator: ", "))
                    .font(CVTheme.body())
                    .foregroundStyle(CVTheme.ink))
            }
        }
    }

    private func educationSection(_ entry: CVDocument.EducationSection) -> some View {
        VStack(alignment: .leading, spacing: metrics.lineGap) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(entry.qualification), \(entry.institution)")
                    .font(CVTheme.semibold())
                    .foregroundStyle(CVTheme.ink)
                Spacer()
                Text(CVDocument.dateRange(start: entry.start, end: entry.end))
                    .font(CVTheme.body(CVTheme.metaSize))
                    .foregroundStyle(CVTheme.meta)
            }
            if !entry.detail.isEmpty {
                Text(entry.detail)
                    .font(CVTheme.body(CVTheme.metaSize))
                    .foregroundStyle(CVTheme.meta)
            }
        }
    }
}

#Preview {
    let document = CVDocument.previewDocument
    let layout = CVLayout(document: document, metrics: CVMetrics())
    return CVPageView(document: document, blocks: layout.pages.first ?? [])
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
                subline: "London, UK · Fintech",
                bullets: [
                    Bullet(
                        title: "Rebuilt the CI pipeline",
                        text: "Drove CI build times down across every product target"
                    )
                ]
            )
        ]
        document.projects = [
            ProjectSection(
                name: "Trail Mapper", link: "github.com/alex/trail-mapper",
                details: "Engineered offline tile caching for a production mapping app."
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
        document.skillCategories = [
            SkillCategory(name: "Platform Engineering", skills: ["CI/CD", "Swift"]),
            SkillCategory(name: "Data", skills: ["SQL"]),
        ]
        document.interests = ["Cycling", "Trail running"]
        return document
    }

    private init() {
        name = ""
        headline = ""
        contactLines = []
        roles = []
        projects = []
        education = []
    }
}

import Foundation
import PDFKit
import Testing

@testable import Ladder

/// The pagination model ([CVEXPORT-24]): blocks are measured with the same
/// faces the view sets, and a page break falls only between blocks.
@MainActor
struct CVLayoutTests {
    /// A document long enough to spill well past one A4 page.
    private var longDocument: CVDocument {
        var document = CVDocument.previewDocument
        document.roles = (1...6).map { roleIndex in
            CVDocument.RoleSection(
                title: "Senior Engineer \(roleIndex)", company: "Acme \(roleIndex)",
                start: Date(timeIntervalSince1970: 1_600_000_000), end: nil,
                subline: "London, UK · Fintech",
                bullets: (1...6).map { bulletIndex in
                    CVDocument.Bullet(
                        title: bulletIndex.isMultiple(of: 2) ? nil : "Lead phrase \(bulletIndex)",
                        text: "Bullet \(bulletIndex) for role \(roleIndex): delivered a measurable improvement, spelling out the constraint it removed, the teams it unblocked, and the metric it moved over two quarters"
                    )
                }
            )
        }
        return document
    }

    @Test("[CVEXPORT-24] a page break never splits a text line")
    func everyBlockLandsWhollyInsideOnePage() throws {
        let metrics = CVMetrics()
        let layout = CVLayout(document: longDocument, metrics: metrics)

        try #require(layout.pages.count > 1, "the fixture document must actually paginate")
        for page in layout.pages {
            // Page-top gap is dropped; every block lands wholly inside the
            // content box — a break can only fall between blocks.
            var y: CGFloat = 0
            for (index, block) in page.enumerated() {
                if index > 0 { y += block.gapAbove }
                y += block.height
            }
            #expect(y <= metrics.contentHeight + 0.5, "a page never overflows its content box")
        }
        // Nothing lost, nothing duplicated, order preserved.
        #expect(layout.pages.flatMap(\.self) == layout.blocks)
    }

    @Test("[CVEXPORT-24] a section header never lands as the last block on a page")
    func sectionHeaderTravelsWithItsFirstBlock() throws {
        // Sweep content lengths so some layout puts a section boundary near
        // a page end — the keep-with-next rule must hold in every one.
        for bulletCount in 1...8 {
            var document = longDocument
            document.roles = document.roles.map { role in
                var role = role
                role.bullets = Array(role.bullets.prefix(bulletCount))
                return role
            }
            let layout = CVLayout(document: document, metrics: CVMetrics())
            for page in layout.pages {
                if let last = page.last, case .sectionHeader = last.kind {
                    Issue.record("a section header ended a page at \(bulletCount) bullets per role")
                }
            }
        }
    }

    @Test("[CVEXPORT-7] a paginated render draws every page at A4 with the tail intact")
    func paginatedRenderKeepsA4AndTailContent() throws {
        let pdfData = CVRenderer.pdfData(for: longDocument)
        let pdf = try #require(PDFDocument(data: pdfData))
        #expect(pdf.pageCount > 1)
        for index in 0..<pdf.pageCount {
            let bounds = try #require(pdf.page(at: index)).bounds(for: .mediaBox)
            #expect(abs(bounds.width - 595.2) <= 1)
            #expect(abs(bounds.height - 841.8) <= 1)
        }
        let text = try #require(pdf.string)
        #expect(text.contains("Bullet 6 for role 6"), "the tail survives pagination")
    }
}

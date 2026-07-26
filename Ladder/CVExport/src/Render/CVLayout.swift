import AppKit
import Foundation

/// One indivisible unit of the rendered CV. A page break may fall only
/// between blocks ([CVEXPORT-24]) — never inside one, so no text line is
/// ever cut at the A4 boundary.
struct CVBlock: Equatable {
    enum Kind: Equatable {
        case identityHeader
        case summary
        case sectionHeader(String)
        /// Role line plus its optional grey subline.
        case roleHeader(role: Int)
        case bullet(role: Int, bullet: Int)
        case project(Int)
        case education(Int)
        case skillsTable
        case interests
    }

    var kind: Kind
    /// Measured with the template's own faces at the template's widths.
    var height: CGFloat
    /// Scaled gap above this block within the flow; dropped at a page top.
    var gapAbove: CGFloat = 0
    /// A section header never ends a page — it travels with the next block.
    var keepWithNext: Bool = false
}

/// Measures a `CVDocument` into blocks and assigns them to A4 pages —
/// the block-aware pagination that replaced tall-view slicing
/// (decisions/0008, [CVEXPORT-24]).
@MainActor
struct CVLayout {
    let blocks: [CVBlock]
    let pages: [[CVBlock]]
    /// Total flowed height (page-top gaps included) — the fit loop's
    /// natural-fill measure ([CVEXPORT-29]).
    let flowedHeight: CGFloat

    init(document: CVDocument, metrics: CVMetrics) {
        blocks = Self.measuredBlocks(for: document, metrics: metrics)
        pages = Self.paginate(blocks, contentHeight: metrics.contentHeight)
        flowedHeight = blocks.enumerated().reduce(0) { total, entry in
            total + entry.element.height + (entry.offset == 0 ? 0 : entry.element.gapAbove)
        }
    }

    // MARK: - Pagination

    /// Pure assignment: blocks in order, `keepWithNext` chains placed
    /// atomically, gap collapsed at each page top. A unit taller than a
    /// page is placed alone rather than dropped.
    static func paginate(_ blocks: [CVBlock], contentHeight: CGFloat) -> [[CVBlock]] {
        var units: [[CVBlock]] = []
        var current: [CVBlock] = []
        for block in blocks {
            current.append(block)
            if !block.keepWithNext {
                units.append(current)
                current = []
            }
        }
        if !current.isEmpty { units.append(current) }

        var pages: [[CVBlock]] = [[]]
        var y: CGFloat = 0
        for unit in units {
            let unitHeight = unit.enumerated().reduce(0) { total, entry in
                total + entry.element.height + (entry.offset == 0 ? 0 : entry.element.gapAbove)
            }
            let gap = pages[pages.count - 1].isEmpty ? 0 : unit[0].gapAbove
            if !pages[pages.count - 1].isEmpty, y + gap + unitHeight > contentHeight {
                pages.append([])
                y = unitHeight
            } else {
                y += gap + unitHeight
            }
            pages[pages.count - 1].append(contentsOf: unit)
        }
        return pages
    }

    // MARK: - Measurement

    private static func measuredBlocks(
        for document: CVDocument, metrics: CVMetrics
    ) -> [CVBlock] {
        let measurer = Measurer(metrics: metrics)
        var blocks: [CVBlock] = []

        blocks.append(CVBlock(
            kind: .identityHeader, height: measurer.identityHeader(document)
        ))
        if !document.summary.isEmpty {
            blocks.append(CVBlock(
                kind: .summary,
                height: measurer.body(document.summary),
                gapAbove: metrics.sectionGap
            ))
        }

        blocks.append(sectionHeader("EXPERIENCE", measurer: measurer, metrics: metrics))
        for (roleIndex, role) in document.roles.enumerated() {
            blocks.append(CVBlock(
                kind: .roleHeader(role: roleIndex),
                height: measurer.roleHeader(role),
                gapAbove: metrics.blockGap,
                keepWithNext: !role.bullets.isEmpty
            ))
            for (bulletIndex, bullet) in role.bullets.enumerated() {
                blocks.append(CVBlock(
                    kind: .bullet(role: roleIndex, bullet: bulletIndex),
                    height: measurer.bullet(bullet),
                    gapAbove: metrics.lineGap
                ))
            }
        }

        if !document.projects.isEmpty {
            blocks.append(sectionHeader("PROJECTS", measurer: measurer, metrics: metrics))
            for (index, project) in document.projects.enumerated() {
                blocks.append(CVBlock(
                    kind: .project(index),
                    height: measurer.project(project),
                    gapAbove: metrics.blockGap
                ))
            }
        }

        if !document.education.isEmpty {
            blocks.append(sectionHeader("EDUCATION", measurer: measurer, metrics: metrics))
            for (index, entry) in document.education.enumerated() {
                blocks.append(CVBlock(
                    kind: .education(index),
                    height: measurer.education(entry),
                    gapAbove: metrics.blockGap
                ))
            }
        }

        if !document.skillCategories.isEmpty {
            blocks.append(sectionHeader("SKILLS", measurer: measurer, metrics: metrics))
            blocks.append(CVBlock(
                kind: .skillsTable,
                height: measurer.skillsTable(document.skillCategories),
                gapAbove: metrics.blockGap
            ))
        }

        if !document.interests.isEmpty {
            blocks.append(sectionHeader("INTERESTS", measurer: measurer, metrics: metrics))
            blocks.append(CVBlock(
                kind: .interests,
                height: measurer.body(document.interests.joined(separator: " · ")),
                gapAbove: metrics.blockGap
            ))
        }

        return blocks
    }

    private static func sectionHeader(
        _ title: String, measurer: Measurer, metrics: CVMetrics
    ) -> CVBlock {
        CVBlock(
            kind: .sectionHeader(title),
            height: measurer.sectionHeader(title),
            gapAbove: metrics.sectionGap,
            keepWithNext: true
        )
    }

    /// Text heights via NSAttributedString with the same registered faces
    /// the view sets, plus a small per-block safety margin so SwiftUI's
    /// layout can never exceed the measured box.
    private struct Measurer {
        let metrics: CVMetrics
        /// Per-text-run safety margin (line-height rounding differences
        /// between AppKit measurement and SwiftUI layout).
        private let fudge: CGFloat = 2

        private func height(_ string: String, fontName: String, size: CGFloat, width: CGFloat) -> CGFloat {
            let font = CVTheme.measuringFont(named: fontName, size: size)
            let bounds = NSAttributedString(string: string, attributes: [.font: font])
                .boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading]
                )
            return ceil(bounds.height) + fudge
        }

        func body(_ string: String) -> CGFloat {
            height(string, fontName: CVTheme.bodyFontName, size: CVTheme.bodySize,
                   width: metrics.contentWidth)
        }

        func identityHeader(_ document: CVDocument) -> CGFloat {
            var total = height(document.name, fontName: CVTheme.nameFontName,
                               size: CVTheme.nameSize, width: metrics.contentWidth)
            if !document.headline.isEmpty {
                total += metrics.lineGap + height(
                    document.headline, fontName: CVTheme.mediumFontName,
                    size: CVTheme.headlineSize, width: metrics.contentWidth)
            }
            if !document.contactLines.isEmpty {
                total += metrics.lineGap + height(
                    document.contactLines.joined(separator: "  ·  "),
                    fontName: CVTheme.bodyFontName, size: CVTheme.metaSize,
                    width: metrics.contentWidth)
            }
            // The thick rule and its top padding.
            total += metrics.lineGap + 2
            return total
        }

        func sectionHeader(_ title: String) -> CGFloat {
            height(title, fontName: CVTheme.semiboldFontName,
                   size: CVTheme.sectionHeaderSize, width: metrics.contentWidth)
                + metrics.lineGap + 1
        }

        func roleHeader(_ role: CVDocument.RoleSection) -> CGFloat {
            // The title/company run shares its line with the right-aligned
            // dates; measure it at the width the dates leave over.
            var total = height("\(role.title), \(role.company)",
                               fontName: CVTheme.semiboldFontName,
                               size: CVTheme.roleTitleSize,
                               width: metrics.contentWidth * 0.68)
            if let subline = role.subline {
                total += metrics.lineGap + height(
                    subline, fontName: CVTheme.bodyFontName,
                    size: CVTheme.metaSize, width: metrics.contentWidth)
            }
            return total
        }

        func bullet(_ bullet: CVDocument.Bullet) -> CGFloat {
            let lead = bullet.title.map { "\($0) - " } ?? ""
            return body("•  \(lead)\(bullet.text)")
        }

        func project(_ project: CVDocument.ProjectSection) -> CGFloat {
            var total = height(project.name, fontName: CVTheme.semiboldFontName,
                               size: CVTheme.roleTitleSize,
                               width: metrics.contentWidth * 0.68)
            if !project.details.isEmpty {
                total += metrics.lineGap + body(project.details)
            }
            return total
        }

        func education(_ entry: CVDocument.EducationSection) -> CGFloat {
            var total = height("\(entry.qualification), \(entry.institution)",
                               fontName: CVTheme.semiboldFontName,
                               size: CVTheme.bodySize,
                               width: metrics.contentWidth * 0.68)
            if !entry.detail.isEmpty {
                total += metrics.lineGap + height(
                    entry.detail, fontName: CVTheme.bodyFontName,
                    size: CVTheme.metaSize, width: metrics.contentWidth)
            }
            return total
        }

        func skillsTable(_ categories: [SkillCategory]) -> CGFloat {
            // Two columns; each grid row is as tall as its taller cell.
            let columnWidth = (metrics.contentWidth - 12) / 2
            var total: CGFloat = 0
            var rows = 0
            var index = 0
            while index < categories.count {
                let pair = categories[index..<min(index + 2, categories.count)]
                let rowHeight = pair.map { category in
                    height("\(category.name): \(category.skills.joined(separator: ", "))",
                           fontName: CVTheme.bodyFontName, size: CVTheme.bodySize,
                           width: columnWidth)
                }.max() ?? 0
                total += rowHeight
                rows += 1
                index += 2
            }
            return total + CGFloat(max(0, rows - 1)) * metrics.lineGap
        }
    }
}

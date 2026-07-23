import Foundation

/// The per-export record of what the fit loop saw and did (decisions/0008,
/// [CVEXPORT-30]) — feedstock for future selection budgets (Baton #162);
/// this slice only records.
struct FitMetrics: Codable, Equatable, Sendable {
    // Content volume sent to render.
    var roleCount: Int
    var bulletCount: Int
    var projectCount: Int
    var skillCount: Int
    var characterCount: Int
    // Settings applied.
    var compactionStep: Int
    var stretchFactor: Double
    // Passes run.
    var condensePassRun: Bool
    var trimPassCount: Int
    var trimmedItemCount: Int
    // Page counts.
    var naturalPageCount: Int
    var finalPageCount: Int
}

/// The automatic ladder that lands every export on at most two pages
/// (decisions/0008): density compaction, then the tailor-owned condense
/// pass, then — terminally, repeated until it fits — the trim pass. Lazy:
/// a fitting render sends no request. Underflow past the 1.5-page
/// threshold stretches spacing toward a flush page two, capped at 1.25×.
@MainActor
struct CVFitLoop {
    struct Outcome {
        var document: CVDocument
        /// The settings the final render must use.
        var metrics: CVMetrics
        var pageCount: Int
        /// Display texts of the items the trim pass removed — the fit
        /// report's trim list ([CVEXPORT-28]).
        var trimmedItems: [String]
        var fitMetrics: FitMetrics
    }

    /// nil when no intelligence service is available — the loop then fails
    /// on content that needs a pass, with the reason surfaced.
    let fitPasses: FitPassRunner?

    private static let pageCap = 2

    func fit(document original: CVDocument, jobDescription: String) async throws -> Outcome {
        let naturalMetrics = CVMetrics()
        let naturalLayout = CVLayout(document: original, metrics: naturalMetrics)
        let naturalPages = naturalLayout.pages.count

        var document = original
        var condensed = false
        var trimPasses = 0
        var trimmedItems: [String] = []

        var fit = Self.firstFittingCompaction(for: document)
        if fit == nil {
            document = try await condensePass(on: document)
            condensed = true
            fit = Self.firstFittingCompaction(for: document)
        }
        while fit == nil {
            let (trimmedDocument, removed) = try await trimPass(
                on: document, jobDescription: jobDescription)
            document = trimmedDocument
            trimPasses += 1
            trimmedItems.append(contentsOf: removed)
            fit = Self.firstFittingCompaction(for: document)
        }
        var (stepIndex, metrics, layout) = fit!

        // Underflow stretch ([CVEXPORT-29]): only a naturally-fitting CV
        // qualifies — overflow content just resolved to the cap is full by
        // definition.
        var stretch: CGFloat = 1
        if stepIndex == 0, !condensed, trimPasses == 0 {
            let fill = layout.flowedHeight / metrics.contentHeight
            if fill > CVMetrics.underflowThreshold, fill < CGFloat(Self.pageCap) {
                stretch = Self.stretchFactor(for: layout, metrics: metrics)
                if stretch > 1 {
                    var stretched = CVMetrics(stretch: stretch)
                    var stretchedLayout = CVLayout(document: document, metrics: stretched)
                    // Back off if pagination rounding pushed a block over.
                    while stretch > 1, stretchedLayout.pages.count > Self.pageCap {
                        stretch = max(1, stretch - 0.02)
                        stretched = CVMetrics(stretch: stretch)
                        stretchedLayout = CVLayout(document: document, metrics: stretched)
                    }
                    metrics = stretched
                    layout = stretchedLayout
                }
            }
        }

        return Outcome(
            document: document,
            metrics: metrics,
            pageCount: layout.pages.count,
            trimmedItems: trimmedItems,
            fitMetrics: FitMetrics(
                roleCount: original.roles.count,
                bulletCount: original.roles.reduce(0) { $0 + $1.bullets.count },
                projectCount: original.projects.count,
                skillCount: original.skillCategories.reduce(0) { $0 + $1.skills.count },
                characterCount: Self.characterCount(of: original),
                compactionStep: stepIndex,
                stretchFactor: Double(stretch),
                condensePassRun: condensed,
                trimPassCount: trimPasses,
                trimmedItemCount: trimmedItems.count,
                naturalPageCount: naturalPages,
                finalPageCount: layout.pages.count
            )
        )
    }

    // MARK: - Compaction

    private static func firstFittingCompaction(
        for document: CVDocument
    ) -> (Int, CVMetrics, CVLayout)? {
        for (index, step) in CVMetrics.compactionSteps.enumerated() {
            let metrics = CVMetrics(compaction: step)
            let layout = CVLayout(document: document, metrics: metrics)
            if layout.pages.count <= pageCap {
                return (index, metrics, layout)
            }
        }
        return nil
    }

    // MARK: - Service passes

    private func requireFitPasses() throws -> FitPassRunner {
        guard let fitPasses else {
            throw TailorValidationFailure(
                reason: "The CV is over two pages and no intelligence service is available for the condense pass."
            )
        }
        return fitPasses
    }

    /// [TAILOR-25]: same selection, shorter texts. Titles never travel —
    /// the pass shortens descriptions alone.
    private func condensePass(on document: CVDocument) async throws -> CVDocument {
        let items = Self.bulletItems(of: document)
        let condensed = try await requireFitPasses().condense(items)
        let textByID = Dictionary(uniqueKeysWithValues: condensed.map { ($0.id, $0.text) })
        var result = document
        result.roles = document.roles.enumerated().map { roleIndex, role in
            var role = role
            role.bullets = role.bullets.enumerated().map { bulletIndex, bullet in
                var bullet = bullet
                bullet.text = textByID["b\(roleIndex)-\(bulletIndex)"] ?? bullet.text
                return bullet
            }
            return role
        }
        return result
    }

    /// [TAILOR-26]: a non-empty strict subset survives. Roles always stay —
    /// employment continuity ([CVEXPORT-3]); only their bullets and whole
    /// projects trim.
    private func trimPass(
        on document: CVDocument, jobDescription: String
    ) async throws -> (CVDocument, removed: [String]) {
        var items = Self.bulletItems(of: document)
        items += document.projects.enumerated().map { index, project in
            FitPassItem(id: "p\(index)", text: "\(project.name): \(project.details)")
        }
        let kept = Set(try await requireFitPasses().trim(items, jobDescription: jobDescription))

        var removed: [String] = []
        var result = document
        result.roles = document.roles.enumerated().map { roleIndex, role in
            var role = role
            role.bullets = role.bullets.enumerated().compactMap { bulletIndex, bullet in
                if kept.contains("b\(roleIndex)-\(bulletIndex)") { return bullet }
                removed.append(bullet.title.map { "\($0) - \(bullet.text)" } ?? bullet.text)
                return nil
            }
            return role
        }
        result.projects = document.projects.enumerated().compactMap { index, project in
            if kept.contains("p\(index)") { return project }
            removed.append(project.name)
            return nil
        }
        return (result, removed)
    }

    /// The loop's deterministic bullet id scheme: "b<role>-<bullet>".
    private static func bulletItems(of document: CVDocument) -> [FitPassItem] {
        document.roles.enumerated().flatMap { roleIndex, role in
            role.bullets.enumerated().map { bulletIndex, bullet in
                FitPassItem(id: "b\(roleIndex)-\(bulletIndex)", text: bullet.text)
            }
        }
    }

    // MARK: - Underflow

    /// Solve for the spacing multiplier that ends flush with page two's
    /// bottom: text heights are fixed, only gaps scale.
    private static func stretchFactor(for layout: CVLayout, metrics: CVMetrics) -> CGFloat {
        let blockHeights = layout.blocks.reduce(0) { $0 + $1.height }
        let gaps = layout.flowedHeight - blockHeights
        guard gaps > 0 else { return 1 }
        let target = CGFloat(pageCap) * metrics.contentHeight
        let needed = (target - blockHeights) / gaps
        return min(max(needed, 1), CVMetrics.stretchCap)
    }

    private static func characterCount(of document: CVDocument) -> Int {
        var total = document.summary.count
        total += document.roles.reduce(0) { sum, role in
            sum + role.bullets.reduce(0) { $0 + $1.text.count + ($1.title?.count ?? 0) }
        }
        total += document.projects.reduce(0) { $0 + $1.details.count }
        return total
    }
}

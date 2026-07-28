import Foundation

/// Feedstock for future selection budgets (Baton #162); this slice only
/// records.
struct FitMetrics: Codable, Equatable, Sendable {
    var roleCount: Int
    var bulletCount: Int
    var projectCount: Int
    var skillCount: Int
    var characterCount: Int
    var compactionStep: Int
    var stretchFactor: Double
    var condensePassRun: Bool
    var trimPassCount: Int
    var trimmedItemCount: Int
    var naturalPageCount: Int
    var finalPageCount: Int
}

@MainActor
struct CVFitLoop {
    struct Outcome {
        var document: CVDocument
        /// The settings the final render must use.
        var metrics: CVMetrics
        var pageCount: Int
        var trimmedItems: [String]
        var fitMetrics: FitMetrics
    }

    let fitPasses: FitPassRunner?

    nonisolated static let pageCap = 2

    func fit(document original: CVDocument, jobDescription: String) async throws -> Outcome {
        let naturalMetrics = CVMetrics()
        let naturalLayout = CVLayout(document: original, metrics: naturalMetrics)
        let naturalPages = naturalLayout.pages.count

        var document = original
        var condensed = false
        var trimPasses = 0
        var trimmedItems: [String] = []

        var settings = Self.settings(for: document, stretching: true)
        if !settings.fits {
            document = try await condensePass(on: document)
            condensed = true
            settings = Self.settings(for: document, stretching: false)
        }
        while !settings.fits {
            let (trimmedDocument, removed) = try await trimPass(
                on: document, jobDescription: jobDescription)
            document = trimmedDocument
            trimPasses += 1
            trimmedItems.append(contentsOf: removed)
            settings = Self.settings(for: document, stretching: false)
        }

        return Outcome(
            document: document,
            metrics: settings.metrics,
            pageCount: settings.pageCount,
            trimmedItems: trimmedItems,
            fitMetrics: FitMetrics(
                roleCount: original.roles.count,
                bulletCount: original.roles.reduce(0) { $0 + $1.bullets.count },
                projectCount: original.projects.count,
                skillCount: original.skillCategories.reduce(0) { $0 + $1.skills.count },
                characterCount: Self.characterCount(of: original),
                compactionStep: settings.stepIndex,
                stretchFactor: Double(settings.stretch),
                condensePassRun: condensed,
                trimPassCount: trimPasses,
                trimmedItemCount: trimmedItems.count,
                naturalPageCount: naturalPages,
                finalPageCount: settings.pageCount
            )
        )
    }

    /// The deterministic half alone, and it never refuses: the edited path
    /// needs the real page count of a CV that overflows. Pass counts and the
    /// trim list carry over from the composition being re-laid-out — only
    /// the compose-time loop ever populates them.
    static func relayout(_ document: CVDocument, carrying previous: Outcome) -> Outcome {
        let settings = settings(for: document, stretching: true)
        var fitMetrics = previous.fitMetrics
        fitMetrics.roleCount = document.roles.count
        fitMetrics.bulletCount = document.roles.reduce(0) { $0 + $1.bullets.count }
        fitMetrics.projectCount = document.projects.count
        fitMetrics.skillCount = document.skillCategories.reduce(0) { $0 + $1.skills.count }
        fitMetrics.characterCount = characterCount(of: document)
        fitMetrics.compactionStep = settings.stepIndex
        fitMetrics.stretchFactor = Double(settings.stretch)
        fitMetrics.finalPageCount = settings.pageCount
        return Outcome(
            document: document,
            metrics: settings.metrics,
            pageCount: settings.pageCount,
            trimmedItems: previous.trimmedItems,
            fitMetrics: fitMetrics
        )
    }

    // MARK: - Compaction

    struct Settings {
        var stepIndex: Int
        var metrics: CVMetrics
        var stretch: CGFloat
        var pageCount: Int
        var fits: Bool
    }

    static func settings(for document: CVDocument, stretching: Bool) -> Settings {
        for (index, step) in CVMetrics.compactionSteps.enumerated() {
            let metrics = CVMetrics(compaction: step)
            let layout = CVLayout(document: document, metrics: metrics)
            guard layout.pages.count <= pageCap else { continue }
            guard stretching, index == 0 else {
                return Settings(
                    stepIndex: index, metrics: metrics, stretch: 1,
                    pageCount: layout.pages.count, fits: true)
            }
            return stretched(document: document, layout: layout, metrics: metrics)
        }
        let stepIndex = CVMetrics.compactionSteps.count - 1
        let metrics = CVMetrics(compaction: CVMetrics.compactionSteps[stepIndex])
        return Settings(
            stepIndex: stepIndex, metrics: metrics, stretch: 1,
            pageCount: CVLayout(document: document, metrics: metrics).pages.count,
            fits: false)
    }

    private static func stretched(
        document: CVDocument, layout: CVLayout, metrics: CVMetrics
    ) -> Settings {
        let natural = Settings(
            stepIndex: 0, metrics: metrics, stretch: 1,
            pageCount: layout.pages.count, fits: true)
        let fill = layout.flowedHeight / metrics.contentHeight
        guard fill > CVMetrics.underflowThreshold, fill < CGFloat(pageCap) else { return natural }
        var stretch = stretchFactor(for: layout, metrics: metrics)
        guard stretch > 1 else { return natural }
        var stretchedMetrics = CVMetrics(stretch: stretch)
        var stretchedLayout = CVLayout(document: document, metrics: stretchedMetrics)
        // Back off if pagination rounding pushed a block over.
        while stretch > 1, stretchedLayout.pages.count > pageCap {
            stretch = max(1, stretch - 0.02)
            stretchedMetrics = CVMetrics(stretch: stretch)
            stretchedLayout = CVLayout(document: document, metrics: stretchedMetrics)
        }
        return Settings(
            stepIndex: 0, metrics: stretchedMetrics, stretch: stretch,
            pageCount: stretchedLayout.pages.count, fits: true)
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

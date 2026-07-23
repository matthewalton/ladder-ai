import CoreGraphics
import Foundation
import Testing

@testable import Ladder

/// The automatic fit loop (decisions/0008): lazy ladder of compaction →
/// condense → trim, plus the underflow stretch. Service passes run through
/// `FixtureIntelligenceService` — bullet ids follow the loop's "b<role>-<n>"
/// scheme, so responses are constructible in advance.
@MainActor
struct CVFitLoopTests {
    private func makeDocument(roles: Int, bulletsPerRole: Int) -> CVDocument {
        var document = CVDocument.previewDocument
        document.roles = (0..<roles).map { roleIndex in
            CVDocument.RoleSection(
                title: "Senior Engineer \(roleIndex)", company: "Acme \(roleIndex)",
                start: Date(timeIntervalSince1970: 1_600_000_000), end: nil,
                bullets: (0..<bulletsPerRole).map { bulletIndex in
                    CVDocument.Bullet(
                        text: "Bullet \(bulletIndex) for role \(roleIndex): delivered a measurable improvement, spelling out the constraint it removed, the teams it unblocked, and the metric it moved over the following two quarters of sustained delivery"
                    )
                }
            )
        }
        return document
    }

    @Test("[CVEXPORT-26] the fit loop sends a condense request only when compaction leaves the CV over two pages")
    func fittingContentSendsNoRequests() async throws {
        let service = FixtureIntelligenceService(returning: Data("{}".utf8))
        let loop = CVFitLoop(fitPasses: FitPassRunner(service: service))

        let outcome = try await loop.fit(
            document: makeDocument(roles: 1, bulletsPerRole: 3), jobDescription: "JD"
        )

        #expect(await service.recordedRequests.isEmpty, "a fitting CV costs zero service calls")
        #expect(outcome.pageCount <= 2)
        #expect(outcome.fitMetrics.condensePassRun == false)
        #expect(outcome.fitMetrics.trimPassCount == 0)
    }

    @Test("[CVEXPORT-25] a rendered CV never exceeds two pages")
    func oversizedContentLandsOnTwoPages() async throws {
        let document = makeDocument(roles: 8, bulletsPerRole: 8)
        // Condense barely helps (echoes every id with near-identical text),
        // forcing the terminal trim; the trim keeps one bullet per role.
        let condensed = Self.condenseResponse(
            ids: Self.bulletIDs(of: document), shorten: false
        )
        let keep = (0..<8).map { "b\($0)-0" }
        let trim = Data(#"{"keep": [\#(keep.map { "\"\($0)\"" }.joined(separator: ","))]}"#.utf8)
        let service = FixtureIntelligenceService(returning: [condensed, trim])
        let loop = CVFitLoop(fitPasses: FitPassRunner(service: service))

        let outcome = try await loop.fit(document: document, jobDescription: "JD")

        #expect(outcome.pageCount <= 2, "the hard cap")
        #expect(outcome.fitMetrics.naturalPageCount > 2)
        #expect(outcome.fitMetrics.finalPageCount == outcome.pageCount)
        // The rendered PDF honours the cap too.
        let pdfData = CVRenderer.pdfData(for: outcome.document, metrics: outcome.metrics)
        let pageCount = try #require(PDFPageCounter.count(of: pdfData))
        #expect(pageCount <= 2)
    }

    @Test("[CVEXPORT-27] the fit loop sends a trim request only when a condensed CV still exceeds two pages")
    func trimRunsOnlyAfterCondenseFallsShort() async throws {
        let document = makeDocument(roles: 8, bulletsPerRole: 8)
        let condensed = Self.condenseResponse(ids: Self.bulletIDs(of: document), shorten: false)
        let trim = Data(#"{"keep": ["b0-0", "b1-0", "b2-0"]}"#.utf8)
        let service = FixtureIntelligenceService(returning: [condensed, trim])
        let loop = CVFitLoop(fitPasses: FitPassRunner(service: service))

        let outcome = try await loop.fit(document: document, jobDescription: "JD")

        let requests = await service.recordedRequests
        #expect(requests.count == 2)
        #expect(requests[0].prompt == (try FitPassPrompts.condense()), "condense before trim, always")
        #expect(requests[1].prompt == (try FitPassPrompts.trim()))
        #expect(outcome.fitMetrics.condensePassRun)
        #expect(outcome.fitMetrics.trimPassCount == 1)
        #expect(!outcome.trimmedItems.isEmpty, "the trim list feeds the fit report ([CVEXPORT-28])")
    }

    @Test("[CVEXPORT-27] a condense that resolves the overflow sends no trim request")
    func sufficientCondenseSkipsTrim() async throws {
        // Just over two pages: condensing to terse bullets resolves it.
        var document = makeDocument(roles: 6, bulletsPerRole: 6)
        var probe = CVLayout(document: document, metrics: CVMetrics(compaction: CVMetrics.compactionSteps.last!))
        var roles = 6
        while probe.pages.count <= 2 {
            roles += 1
            document = makeDocument(roles: roles, bulletsPerRole: 6)
            probe = CVLayout(document: document, metrics: CVMetrics(compaction: CVMetrics.compactionSteps.last!))
        }
        let condensed = Self.condenseResponse(ids: Self.bulletIDs(of: document), shorten: true)
        let service = FixtureIntelligenceService(returning: condensed)
        let loop = CVFitLoop(fitPasses: FitPassRunner(service: service))

        let outcome = try await loop.fit(document: document, jobDescription: "JD")

        #expect(outcome.pageCount <= 2)
        #expect(await service.recordedRequests.count == 1, "condense sufficed — no trim request")
        #expect(outcome.fitMetrics.trimPassCount == 0)
        #expect(outcome.trimmedItems.isEmpty)
    }

    @Test("[CVEXPORT-29] a CV naturally filling more than one and a half pages renders with stretched spacing")
    func underfullSecondPageStretchesSpacing() async throws {
        // Grow until the natural render lands between ~1.55 and ~1.95 pages.
        var bullets = 8
        var document = makeDocument(roles: 3, bulletsPerRole: bullets)
        func fill(_ document: CVDocument) -> CGFloat {
            let metrics = CVMetrics()
            return CVLayout(document: document, metrics: metrics).flowedHeight / metrics.contentHeight
        }
        while fill(document) <= 1.55 {
            bullets += 1
            document = makeDocument(roles: 3, bulletsPerRole: bullets)
        }
        try #require(fill(document) < 1.95, "the fixture must land inside the underflow band")

        let service = FixtureIntelligenceService(returning: Data("{}".utf8))
        let loop = CVFitLoop(fitPasses: FitPassRunner(service: service))
        let outcome = try await loop.fit(document: document, jobDescription: "JD")

        #expect(outcome.fitMetrics.stretchFactor > 1.0, "spacing stretches toward a flush page two")
        #expect(outcome.fitMetrics.stretchFactor <= Double(CVMetrics.stretchCap) + 0.001,
                "the cap wins over flushness")
        #expect(outcome.pageCount <= 2)
        #expect(await service.recordedRequests.isEmpty)
    }

    @Test("[CVEXPORT-29] a CV at or under the threshold renders at natural spacing")
    func shortContentRendersNatural() async throws {
        let service = FixtureIntelligenceService(returning: Data("{}".utf8))
        let loop = CVFitLoop(fitPasses: FitPassRunner(service: service))

        let outcome = try await loop.fit(
            document: makeDocument(roles: 1, bulletsPerRole: 2), jobDescription: "JD"
        )

        #expect(outcome.fitMetrics.stretchFactor == 1.0,
                "one strong page beats one page plus a straggler")
    }

    // MARK: - Fixture plumbing

    /// The loop's deterministic bullet id scheme.
    private static func bulletIDs(of document: CVDocument) -> [String] {
        document.roles.enumerated().flatMap { roleIndex, role in
            role.bullets.indices.map { "b\(roleIndex)-\($0)" }
        }
    }

    private static func condenseResponse(ids: [String], shorten: Bool) -> Data {
        let items = ids.map { id in
            let text = shorten
                ? "Tersely delivered improvement \(id)"
                : "Delivered a measurable improvement, spelling out the constraint it removed, the teams it unblocked, and the metric it moved over the following two quarters of delivery \(id)"
            return #"{"id": "\#(id)", "text": "\#(text)"}"#
        }
        return Data(#"{"items": [\#(items.joined(separator: ","))]}"#.utf8)
    }
}

/// PDF page counting without PDFKit imports sprinkled through the tests.
enum PDFPageCounter {
    static func count(of data: Data) -> Int? {
        guard let provider = CGDataProvider(data: data as CFData),
              let document = CGPDFDocument(provider) else { return nil }
        return document.numberOfPages
    }
}

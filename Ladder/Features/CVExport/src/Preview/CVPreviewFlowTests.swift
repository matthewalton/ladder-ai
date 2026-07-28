import Foundation
import PDFKit
import SwiftData
import Testing

@testable import Ladder

@MainActor
struct CVPreviewFlowTests {
    private func expectUntouched(
        _ application: Application, _ comment: Comment
    ) {
        #expect(application.cvSnapshot == nil, comment)
        #expect(application.cvSelectionRationale == nil, comment)
        #expect(application.fitMetrics == nil, comment)
        #expect(application.status == .draft, comment)
        #expect(application.appliedAt == nil, comment)
        #expect(application.company == "Summit Labs", comment)
        #expect(application.roleTitle == "Platform Engineer", comment)
        #expect(application.jobDescription == CVPreviewFixture.jobDescription, comment)
        #expect(application.notes.isEmpty, comment)
    }

    @Test("[CVEXPORT-35] when a CV is composed, nothing is written to the store")
    func composingWritesNothing() async throws {
        let profileStore = try CVPreviewFixture.profileStore()
        let profile = try #require(profileStore.profile)
        let review = try CVPreviewFixture.review(profileStore: profileStore)
        let draft = try CVPreviewFixture.draft(in: profileStore.container)
        let createdAt = draft.createdAt
        let store = CVExportStore(container: profileStore.container)

        let composition = try await store.compose(
            profile: profile, review: review, for: draft.persistentModelID)

        #expect(!composition.pdfData.isEmpty, "composing still produced a rendered CV")
        let context = ModelContext(profileStore.container)
        let applications = try context.fetch(FetchDescriptor<Application>())
        #expect(applications.count == 1, "composing inserts nothing")
        let persisted = try #require(applications.first)
        expectUntouched(persisted, "composing persists nothing")
        #expect(persisted.createdAt == createdAt)
    }

    @Test("[CVEXPORT-35] a composition whose fit loop spends both passes still writes nothing")
    func composingWithBothFitPassesWritesNothing() async throws {
        let profileStore = try CVPreviewFixture.oversizedProfileStore()
        let profile = try #require(profileStore.profile)
        let review = try CVPreviewFixture.oversizedReview(profileStore: profileStore)
        let draft = try CVPreviewFixture.draft(in: profileStore.container)
        let service = CVPreviewFixture.bothPassesService(bullets: 100, keep: 3)
        let store = CVExportStore(container: profileStore.container)

        let composition = try await store.compose(
            profile: profile, review: review, for: draft.persistentModelID,
            fitPasses: FitPassRunner(service: service))

        #expect(await service.recordedRequests.count == 2, "composing is not free — both passes ran")
        #expect(composition.fitMetrics.condensePassRun)
        #expect(composition.fitMetrics.trimPassCount == 1)
        let persisted = try CVPreviewFixture.application(
            draft.persistentModelID, in: profileStore.container)
        expectUntouched(persisted, "cost is not persistence")
    }

    @Test("[CVEXPORT-35] composing three CVs and exporting none leaves the store as it was")
    func composingRepeatedlyLeavesTheStoreAsItWas() async throws {
        let profileStore = try CVPreviewFixture.profileStore()
        let profile = try #require(profileStore.profile)
        let review = try CVPreviewFixture.review(profileStore: profileStore)
        let draft = try CVPreviewFixture.draft(in: profileStore.container)
        let store = CVExportStore(container: profileStore.container)

        for _ in 1...3 {
            _ = try await store.compose(
                profile: profile, review: review, for: draft.persistentModelID)
        }

        let context = ModelContext(profileStore.container)
        #expect(try context.fetch(FetchDescriptor<Application>()).count == 1)
        expectUntouched(
            try CVPreviewFixture.application(draft.persistentModelID, in: profileStore.container),
            "three compositions, nothing on record")
    }

    @Test("[CVEXPORT-36] the CV preview presents every page of the composed CV")
    func previewPresentsEveryComposedPage() async throws {
        let harness = try await CVPreviewFixture.harness()

        let pdf = try #require(PDFDocument(data: harness.model.pdfData))
        #expect(pdf.pageCount == harness.model.pageCount, "every composed page, none dropped")
        let composed = CVRenderer.pdfData(
            for: harness.model.composition.document,
            metrics: harness.model.composition.fit.metrics)
        #expect(
            try CVPreviewFixture.extractedText(of: harness.model.pdfData)
                == CVPreviewFixture.extractedText(of: composed),
            "the pages themselves, never a second arrangement that could drift")
        expectUntouched(try harness.application, "the preview shows a CV nothing has recorded")
    }

    @Test("[CVEXPORT-37] the fit report appears in the preview before anything is persisted")
    func fitReportAppearsBeforePersistence() async throws {
        let harness = try await CVPreviewFixture.harness()

        let report = harness.model.fitReport
        #expect(report.gaps == ["The JD asks for Kubernetes; nothing selected mentions it"])
        #expect(report.rationale == "CI work maps directly to the JD's platform focus.")
        #expect(report.strengths.contains("Drove CI build times down across every product target"))
        #expect(report.trimmed.isEmpty)
        expectUntouched(try harness.application, "read while there is still a way back")
    }

    @Test("[CVEXPORT-37] a trimmed composition shows its trim list in the preview")
    func trimmedCompositionShowsItsTrimListInThePreview() async throws {
        let profileStore = try CVPreviewFixture.oversizedProfileStore()
        let profile = try #require(profileStore.profile)
        let review = try CVPreviewFixture.oversizedReview(profileStore: profileStore)
        let draft = try CVPreviewFixture.draft(in: profileStore.container)
        let service = CVPreviewFixture.bothPassesService(bullets: 100, keep: 3)
        let store = CVExportStore(container: profileStore.container)

        let composition = try await store.compose(
            profile: profile, review: review, for: draft.persistentModelID,
            fitPasses: FitPassRunner(service: service))

        #expect(!composition.fitReport.trimmed.isEmpty)
        expectUntouched(
            try CVPreviewFixture.application(draft.persistentModelID, in: profileStore.container),
            "the trim list is actionable because nothing is on record yet")
    }

    @Test("[CVEXPORT-16] a point added in the preview is a strength like any other")
    func addedPointBecomesAStrength() async throws {
        let harness = try await CVPreviewFixture.harness()
        let added = try CVPreviewFixture.achievement(
            "Shipped the offline sync engine", in: harness.profileStore)

        harness.model.setSelected(added, true)

        #expect(harness.model.fitReport.strengths.contains("Shipped the offline sync engine"))
    }

    @Test("[CVEXPORT-59] when the edited CV runs over two pages, export is refused")
    func overLengthEditRefusesExport() async throws {
        let harness = try await CVPreviewFixture.harness(extraBullets: 40)
        for role in harness.profile.roles {
            for achievement in role.achievements {
                harness.model.setSelected(achievement, true)
            }
        }

        #expect(harness.model.pageCount > 2, "the edit really is over the cap")
        #expect(!harness.model.canExport)
        #expect(harness.model.pagesOverCap >= 1, "the preview says roughly by how much")
        #expect(throws: CVExportError.overTwoPages(harness.model.pageCount)) {
            try harness.exportStore.export(
                harness.model.composition, into: harness.applicationID)
        }
        expectUntouched(try harness.application, "a refused export persists nothing")
    }

    @Test("[CVEXPORT-59] unticking enough to come back under two pages allows the export")
    func resolvingTheOverflowAllowsTheExport() async throws {
        let harness = try await CVPreviewFixture.harness(extraBullets: 40)
        let extras = harness.profile.roles
            .flatMap(\.achievements)
            .filter { $0.text.hasPrefix("Extra point") }
        for achievement in extras { harness.model.setSelected(achievement, true) }
        try #require(harness.model.pageCount > 2)

        for achievement in extras { harness.model.setSelected(achievement, false) }

        #expect(harness.model.canExport)
        try harness.exportStore.export(harness.model.composition, into: harness.applicationID)
        #expect(try harness.application.cvSnapshot != nil)
    }

    @Test("[CVEXPORT-60] an edited CV within two pages exports exactly as an unedited one does")
    func editedCVExportsLikeAnUneditedOne() async throws {
        let harness = try await CVPreviewFixture.harness()
        let added = try CVPreviewFixture.achievement(
            "Shipped the offline sync engine", in: harness.profileStore)
        let removed = try CVPreviewFixture.achievement(
            "Built the reporting stack", in: harness.profileStore)
        let reworded = try CVPreviewFixture.achievement(
            "Cut CI build times across every product target", in: harness.profileStore)
        harness.model.setSelected(added, true)
        harness.model.setSelected(removed, false)
        harness.model.reword(reworded, to: "Halved CI build times across every product target")
        try #require(harness.model.canExport)

        let export = try harness.exportStore.export(
            harness.model.composition, into: harness.applicationID)

        let application = try harness.application
        #expect(application.cvSnapshot == harness.model.pdfData, "the render the preview last showed")
        #expect(
            application.cvSelectionRationale == "CI work maps directly to the JD's platform focus.",
            "verbatim, exactly as an unedited export")
        #expect(application.fitMetrics != nil)
        #expect(application.status == .applied)
        #expect(application.appliedAt != nil)
        let document = PDFFileDocument(data: export.pdfData)
        #expect(try document.fileWrapper().regularFileContents == application.cvSnapshot)
        let text = try CVPreviewFixture.extractedText(of: try #require(application.cvSnapshot))
        #expect(text.contains("Halved CI build times across every product target"))
        #expect(text.contains("Shipped the offline sync engine"))
    }

    @Test("[CVEXPORT-61] the fit loop's condense and trim passes never run over hand-edited content")
    func editingNeverSpendsAFitPass() async throws {
        let service = FixtureIntelligenceService(returning: Data("{}".utf8))
        let harness = try await CVPreviewFixture.harness(
            extraBullets: 40, fitPasses: FitPassRunner(service: service))
        try #require(await service.recordedRequests.isEmpty, "the composition fitted on its own")

        for role in harness.profile.roles {
            for achievement in role.achievements {
                harness.model.setSelected(achievement, true)
            }
        }

        #expect(harness.model.pageCount > 2, "far over two pages, and still no pass ran")
        #expect(await service.recordedRequests.isEmpty)
    }

    @Test("[CVEXPORT-62] closing the preview with edits pending asks for confirmation first")
    func closingWithPendingEditsAsksFirst() async throws {
        let harness = try await CVPreviewFixture.harness()
        let added = try CVPreviewFixture.achievement(
            "Shipped the offline sync engine", in: harness.profileStore)
        harness.model.setSelected(added, true)

        harness.model.requestClose()

        #expect(harness.model.isConfirmingDiscard)
        #expect(!harness.model.isClosed, "nothing closes until the user rules on it")
    }

    @Test("[CVEXPORT-62] cancelling the confirmation leaves the preview exactly as it was")
    func cancellingTheConfirmationKeepsTheEdits() async throws {
        let harness = try await CVPreviewFixture.harness()
        let added = try CVPreviewFixture.achievement(
            "Shipped the offline sync engine", in: harness.profileStore)
        harness.model.setSelected(added, true)
        let pdfData = harness.model.pdfData
        harness.model.requestClose()

        harness.model.cancelDiscard()

        #expect(!harness.model.isConfirmingDiscard)
        #expect(!harness.model.isClosed)
        #expect(harness.model.isSelected(added), "edits included")
        #expect(harness.model.pdfData == pdfData)
    }

    @Test("[CVEXPORT-62] confirming discards the edits and leaves the Application untouched")
    func confirmingDiscardsTheEdits() async throws {
        let harness = try await CVPreviewFixture.harness()
        let added = try CVPreviewFixture.achievement(
            "Shipped the offline sync engine", in: harness.profileStore)
        harness.model.setSelected(added, true)
        harness.model.requestClose()

        harness.model.confirmDiscard()

        #expect(harness.model.isClosed)
        #expect(!harness.model.hasPendingEdits, "discarded edits do not come back")
        expectUntouched(try harness.application, "closing the preview records nothing")
    }

    @Test("[CVEXPORT-62] a preview with no pending edits closes without asking")
    func closingWithNoPendingEditsAsksNothing() async throws {
        let harness = try await CVPreviewFixture.harness()

        harness.model.requestClose()

        #expect(!harness.model.isConfirmingDiscard)
        #expect(harness.model.isClosed)
    }

    @Test("[CVEXPORT-63] a Tag applied in the preview survives discarding the preview's edits")
    func appliedTagSurvivesDiscard() async throws {
        let harness = try await CVPreviewFixture.harness()
        let point = try CVPreviewFixture.achievement(
            "Built the reporting stack", in: harness.profileStore)

        try harness.model.applyTag(named: "Kubernetes", to: point)
        harness.model.setSelected(point, false)
        harness.model.requestClose()
        harness.model.confirmDiscard()

        let profile = try #require(harness.profileStore.profile)
        #expect(
            profile.skills.contains { $0.name == "Kubernetes" },
            "the Tag is on the Profile's pool")
        #expect(
            point.skills.contains { $0.name == "Kubernetes" },
            "and on the point it was applied to — the model learns what it missed either way")
    }
}

import Foundation
import PDFKit
import SwiftData
import SwiftUI
import Testing

@testable import Ladder

/// A tailor run driven to review with the fixture intelligence service, then
/// exported into a pre-created draft Application (decisions/0006). No test
/// touches the network or the real save panel.
@MainActor
struct CVExportFlowTests {
    /// One role, three achievements — payload ids a1, a2, a3 in sort order.
    /// The bundled tailor-result fixture selects a1 and a3.
    private func makeProfileStore() throws -> ProfileStore {
        let store = try ProfileStore(container: ProfileStore.container(inMemory: true))
        try store.load()
        try store.createProfile(name: "Alex Climber", headline: "Staff Engineer")
        let role = try store.addRole(
            company: "Acme", title: "Senior Engineer",
            start: Date(timeIntervalSince1970: 1_600_000_000), end: nil
        )
        try store.addAchievement(to: role, text: "Cut CI build times across every product target")
        try store.addAchievement(to: role, text: "Shipped the offline sync engine")
        try store.addAchievement(to: role, text: "Led incident response for the payments outage")
        return store
    }

    /// The application the tailor would have started from ([PIPEBOARD-35]):
    /// a draft with its details already on it.
    @discardableResult
    private func makeDraft(
        in container: ModelContainer,
        status: ApplicationStatus = .draft,
        appliedAt: Date? = nil
    ) throws -> Application {
        let context = ModelContext(container)
        let application = Application(
            company: "Summit Labs", roleTitle: "Platform Engineer",
            jobDescription: "Own platform reliability. Kubernetes, CI at scale, incident response.",
            status: status, appliedAt: appliedAt
        )
        context.insert(application)
        try context.save()
        return application
    }

    /// Drives the tailor flow to review with the bundled fixture.
    private func makeReview(profileStore: ProfileStore) async throws -> TailorReview {
        let tailorStore = TailorStore(
            profileStore: profileStore,
            keyStore: InMemoryAPIKeyStore(key: "sk-test"),
            makeIntelligence: { _ in FixtureIntelligenceService.tailorFixture() }
        )
        await tailorStore.startRun(
            JobDetails(
                company: "Summit Labs",
                roleTitle: "Platform Engineer",
                jobDescription: "Own platform reliability. Kubernetes, CI at scale, incident response."
            ))
        return try #require(tailorStore.review)
    }

    private func fetchOnly(in container: ModelContainer) throws -> Application {
        let context = ModelContext(container)
        let applications = try context.fetch(FetchDescriptor<Application>())
        #expect(applications.count == 1)
        return try #require(applications.first)
    }

    @Test("[CVEXPORT-1] exporting a reviewed outcome attaches the rendered CV to the application as its snapshot")
    func exportAttachesRenderedCVToApplication() async throws {
        let profileStore = try makeProfileStore()
        let review = try await makeReview(profileStore: profileStore)
        let draft = try makeDraft(in: profileStore.container)
        let exportStore = CVExportStore(container: profileStore.container)

        let export = try await exportStore.export(
            profile: try #require(profileStore.profile),
            review: review,
            into: draft.persistentModelID
        )

        let persisted = try fetchOnly(in: profileStore.container)
        #expect(persisted.persistentModelID == draft.persistentModelID, "attached, never a fresh row")
        let snapshot = try #require(persisted.cvSnapshot)
        #expect(PDFDocument(data: snapshot) != nil, "the snapshot decodes as a PDF")
        #expect(export.application.cvSnapshot == snapshot)
    }

    @Test("[CVEXPORT-1] exporting into a missing application throws and persists nothing")
    func exportIntoMissingApplicationThrows() async throws {
        let profileStore = try makeProfileStore()
        let review = try await makeReview(profileStore: profileStore)
        let draft = try makeDraft(in: profileStore.container)
        let context = ModelContext(profileStore.container)
        let id = draft.persistentModelID
        try context.delete(model: Application.self)
        try context.save()
        let exportStore = CVExportStore(container: profileStore.container)

        await #expect(throws: CVExportError.applicationMissing) {
            _ = try await exportStore.export(
                profile: try #require(profileStore.profile), review: review, into: id)
        }
        #expect(try context.fetch(FetchDescriptor<Application>()).isEmpty)
    }

    @Test("[CVEXPORT-30] each export persists its fit metrics")
    func exportPersistsFitMetrics() async throws {
        let profileStore = try makeProfileStore()
        let review = try await makeReview(profileStore: profileStore)
        let draft = try makeDraft(in: profileStore.container)
        let exportStore = CVExportStore(container: profileStore.container)

        try await exportStore.export(
            profile: try #require(profileStore.profile),
            review: review,
            into: draft.persistentModelID
        )

        let persisted = try fetchOnly(in: profileStore.container)
        let metrics = try #require(persisted.fitMetrics, "one export, one record")
        // The fixture selection: one role, two selected bullets, no
        // projects — fits naturally, so the loop records a pass-free run.
        #expect(metrics.roleCount == 1)
        #expect(metrics.bulletCount == 2)
        #expect(metrics.projectCount == 0)
        #expect(metrics.characterCount > 0)
        #expect(metrics.finalPageCount >= 1)
        #expect(metrics.naturalPageCount == metrics.finalPageCount)
        #expect(metrics.condensePassRun == false)
        #expect(metrics.trimPassCount == 0)
        #expect(metrics.compactionStep == 0)
    }

    @Test("[CVEXPORT-8] an export leaves the application's company, role title and job description untouched")
    func exportLeavesJobDetailsUntouched() async throws {
        let profileStore = try makeProfileStore()
        let review = try await makeReview(profileStore: profileStore)
        let draft = try makeDraft(in: profileStore.container)
        let exportStore = CVExportStore(container: profileStore.container)

        try await exportStore.export(
            profile: try #require(profileStore.profile), review: review,
            into: draft.persistentModelID
        )

        let application = try fetchOnly(in: profileStore.container)
        #expect(application.company == "Summit Labs")
        #expect(application.roleTitle == "Platform Engineer")
        #expect(
            application.jobDescription
                == "Own platform reliability. Kubernetes, CI at scale, incident response.",
            "character for character — export writes only its own fields"
        )
    }

    @Test("[CVEXPORT-9] the application stores the selection rationale verbatim")
    func applicationStoresRationaleVerbatim() async throws {
        let profileStore = try makeProfileStore()
        let review = try await makeReview(profileStore: profileStore)
        let draft = try makeDraft(in: profileStore.container)
        let exportStore = CVExportStore(container: profileStore.container)

        try await exportStore.export(
            profile: try #require(profileStore.profile), review: review,
            into: draft.persistentModelID
        )

        let application = try fetchOnly(in: profileStore.container)
        #expect(
            application.cvSelectionRationale
                == "CI and incident-response work map directly to the JD's platform-reliability focus; the sync engine achievement is a weaker fit.",
            "character for character — never summarised, trimmed, or re-derived"
        )
    }

    @Test("[CVEXPORT-10] an export flips a draft application to applied and stamps its applied date")
    func exportFlipsDraftToApplied() async throws {
        let profileStore = try makeProfileStore()
        let review = try await makeReview(profileStore: profileStore)
        let draft = try makeDraft(in: profileStore.container)
        #expect(draft.appliedAt == nil)
        let exportStore = CVExportStore(container: profileStore.container)

        try await exportStore.export(
            profile: try #require(profileStore.profile), review: review,
            into: draft.persistentModelID
        )

        let application = try fetchOnly(in: profileStore.container)
        #expect(application.status == .applied, "exporting is the act of applying")
        #expect(application.appliedAt != nil, "the applied date stamps at export")
    }

    @Test("[CVEXPORT-10] an application past draft keeps its status and applied date")
    func exportLeavesNonDraftStatusAlone() async throws {
        let profileStore = try makeProfileStore()
        let review = try await makeReview(profileStore: profileStore)
        let ownDate = Date(timeIntervalSince1970: 1_770_900_000)
        let active = try makeDraft(in: profileStore.container, status: .active, appliedAt: ownDate)
        let exportStore = CVExportStore(container: profileStore.container)

        try await exportStore.export(
            profile: try #require(profileStore.profile), review: review,
            into: active.persistentModelID
        )

        let application = try fetchOnly(in: profileStore.container)
        #expect(application.status == .active)
        #expect(application.appliedAt == ownDate, "an existing date is never overwritten")
    }

    @Test("[CVEXPORT-12] the saved PDF file is byte-identical to the persisted snapshot")
    func savedFileMatchesSnapshotBytes() async throws {
        let profileStore = try makeProfileStore()
        let review = try await makeReview(profileStore: profileStore)
        let draft = try makeDraft(in: profileStore.container)
        let exportStore = CVExportStore(container: profileStore.container)

        let export = try await exportStore.export(
            profile: try #require(profileStore.profile), review: review,
            into: draft.persistentModelID
        )

        // The FileDocument wraps the export's bytes; tests never drive the
        // real save dialog.
        let document = PDFFileDocument(data: export.pdfData)
        let written = try #require(document.fileWrapper().regularFileContents)
        #expect(written == export.application.cvSnapshot, "one render, two destinations — never a second render")
    }

    @Test("[CVEXPORT-22] exporting into an application creates no new Application")
    func exportCreatesNoNewApplication() async throws {
        let profileStore = try makeProfileStore()
        let review = try await makeReview(profileStore: profileStore)
        let draft = try makeDraft(in: profileStore.container)
        let exportStore = CVExportStore(container: profileStore.container)

        try await exportStore.export(
            profile: try #require(profileStore.profile), review: review,
            into: draft.persistentModelID
        )

        let application = try fetchOnly(in: profileStore.container)
        #expect(application.cvSnapshot != nil)
        #expect(application.cvSelectionRationale != nil)
    }

    @Test("[CVEXPORT-14] an export leaves the persisted Profile unchanged")
    func exportLeavesPersistedProfileUnchanged() async throws {
        // On-disk store, reopened after the flow.
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }

        do {
            let profileStore = try ProfileStore(container: ProfileStore.container(at: url))
            try profileStore.load()
            try profileStore.createProfile(name: "Alex Climber", headline: "Staff Engineer")
            let role = try profileStore.addRole(
                company: "Acme", title: "Senior Engineer",
                start: Date(timeIntervalSince1970: 1_600_000_000), end: nil
            )
            try profileStore.addAchievement(to: role, text: "Cut CI build times across every product target")
            try profileStore.addAchievement(to: role, text: "Shipped the offline sync engine")
            try profileStore.addAchievement(to: role, text: "Led incident response for the payments outage")

            let review = try await makeReview(profileStore: profileStore)
            let draft = try makeDraft(in: profileStore.container)
            let exportStore = CVExportStore(container: profileStore.container)
            try await exportStore.export(
                profile: try #require(profileStore.profile), review: review,
                into: draft.persistentModelID
            )
        }

        let reopened = try ProfileStore(container: ProfileStore.container(at: url))
        try reopened.load()
        let profile = try #require(reopened.profile)
        #expect(profile.roles.count == 1)
        let role = try #require(profile.roles.first)
        #expect(role.orderedAchievements.map(\.text) == [
            "Cut CI build times across every product target",
            "Shipped the offline sync engine",
            "Led incident response for the payments outage",
        ], "reviewed text never lands back on the canon")
        #expect(profile.skills.isEmpty)
        // The only persisted change is on the Application the export
        // attached to.
        let context = ModelContext(reopened.container)
        #expect(try context.fetch(FetchDescriptor<Application>()).count == 1)
    }
}

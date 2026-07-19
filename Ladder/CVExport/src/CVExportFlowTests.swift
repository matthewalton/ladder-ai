import Foundation
import PDFKit
import SwiftData
import Testing

@testable import Ladder

/// A tailor run driven to review with the fixture intelligence service, then
/// exported. No test touches the network or the real save panel.
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

    private var jobDetails: JobDetails {
        JobDetails(
            company: "Summit Labs",
            roleTitle: "Platform Engineer",
            jobDescription: "Own platform reliability. Kubernetes, CI at scale, incident response."
        )
    }

    /// Drives the tailor flow to review with the bundled fixture.
    private func makeReview(profileStore: ProfileStore) async throws -> TailorReview {
        let tailorStore = TailorStore(
            profileStore: profileStore,
            keyStore: InMemoryAPIKeyStore(key: "sk-test"),
            makeIntelligence: { _ in FixtureIntelligenceService.tailorFixture() }
        )
        await tailorStore.startRun(jobDetails)
        return try #require(tailorStore.review)
    }

    @Test("[CVEXPORT-1] exporting a reviewed outcome persists an Application carrying the rendered CV as its snapshot")
    func exportPersistsApplicationWithRenderedCV() async throws {
        let profileStore = try makeProfileStore()
        let review = try await makeReview(profileStore: profileStore)
        let exportStore = CVExportStore(container: profileStore.container)

        let export = try exportStore.export(
            profile: try #require(profileStore.profile),
            review: review,
            details: jobDetails
        )

        let context = ModelContext(profileStore.container)
        let applications = try context.fetch(FetchDescriptor<Application>())
        #expect(applications.count == 1)
        let snapshot = try #require(applications.first?.cvSnapshot)
        #expect(PDFDocument(data: snapshot) != nil, "the snapshot decodes as a PDF")
        #expect(export.application.cvSnapshot == snapshot)
    }

    @Test("[CVEXPORT-8] the persisted Application carries the tailor sheet's company, role title and job description")
    func applicationCarriesJobDetails() async throws {
        let profileStore = try makeProfileStore()
        let review = try await makeReview(profileStore: profileStore)
        let exportStore = CVExportStore(container: profileStore.container)

        try exportStore.export(
            profile: try #require(profileStore.profile), review: review, details: jobDetails
        )

        let context = ModelContext(profileStore.container)
        let application = try #require(try context.fetch(FetchDescriptor<Application>()).first)
        #expect(application.company == "Summit Labs")
        #expect(application.roleTitle == "Platform Engineer")
        #expect(application.jobDescription == "Own platform reliability. Kubernetes, CI at scale, incident response.")
    }

    @Test("[CVEXPORT-9] the persisted Application stores the selection rationale verbatim")
    func applicationStoresRationaleVerbatim() async throws {
        let profileStore = try makeProfileStore()
        let review = try await makeReview(profileStore: profileStore)
        let exportStore = CVExportStore(container: profileStore.container)

        try exportStore.export(
            profile: try #require(profileStore.profile), review: review, details: jobDetails
        )

        let context = ModelContext(profileStore.container)
        let application = try #require(try context.fetch(FetchDescriptor<Application>()).first)
        #expect(
            application.cvSelectionRationale
                == "CI and incident-response work map directly to the JD's platform-reliability focus; the sync engine achievement is a weaker fit.",
            "character for character — never summarised, trimmed, or re-derived"
        )
    }

    @Test("[CVEXPORT-10] an export creates the Application with status applied")
    func exportCreatesApplicationAsApplied() async throws {
        let profileStore = try makeProfileStore()
        let review = try await makeReview(profileStore: profileStore)
        let exportStore = CVExportStore(container: profileStore.container)

        try exportStore.export(
            profile: try #require(profileStore.profile), review: review, details: jobDetails
        )

        let context = ModelContext(profileStore.container)
        let application = try #require(try context.fetch(FetchDescriptor<Application>()).first)
        #expect(application.status == .applied, "no draft state in this slice (SPEC.md body)")
    }

    @Test("[CVEXPORT-12] the saved PDF file is byte-identical to the persisted snapshot")
    func savedFileMatchesSnapshotBytes() async throws {
        let profileStore = try makeProfileStore()
        let review = try await makeReview(profileStore: profileStore)
        let exportStore = CVExportStore(container: profileStore.container)

        let export = try exportStore.export(
            profile: try #require(profileStore.profile), review: review, details: jobDetails
        )

        // The FileDocument wraps the export's bytes; tests never drive the
        // real save dialog.
        let document = PDFFileDocument(data: export.pdfData)
        let written = try #require(document.fileWrapper().regularFileContents)
        #expect(written == export.application.cvSnapshot, "one render, two destinations — never a second render")
    }

    @Test("[CVEXPORT-13] exporting twice for the same job creates two Applications")
    func repeatExportCreatesASecondApplication() async throws {
        let profileStore = try makeProfileStore()
        let review = try await makeReview(profileStore: profileStore)
        let exportStore = CVExportStore(container: profileStore.container)
        let profile = try #require(profileStore.profile)

        // Same job details both times — no dedup, no refusal.
        try exportStore.export(profile: profile, review: review, details: jobDetails)
        try exportStore.export(profile: profile, review: review, details: jobDetails)

        let context = ModelContext(profileStore.container)
        let applications = try context.fetch(FetchDescriptor<Application>())
        #expect(applications.count == 2, "each export is its own historical record")
        #expect(applications.allSatisfy { $0.cvSnapshot != nil })
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
            let exportStore = CVExportStore(container: profileStore.container)
            try exportStore.export(
                profile: try #require(profileStore.profile), review: review, details: jobDetails
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
        // The only new persisted object is the Application.
        let context = ModelContext(reopened.container)
        #expect(try context.fetch(FetchDescriptor<Application>()).count == 1)
    }
}

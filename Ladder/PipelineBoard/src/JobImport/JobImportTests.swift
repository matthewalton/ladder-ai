import Foundation
import SwiftData
import SwiftUI
import Testing

@testable import Ladder

/// Fixture files load from the app bundle's Fixtures folder (tests run in
/// the app host). The sample-cv fixture doubles as the posting PDF — the
/// import never inspects what the text says, only that it extracts.
@MainActor
struct JobImportTests {
    private func fixtureURL(_ name: String, _ ext: String) throws -> URL {
        try #require(
            Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Fixtures"),
            "\(name).\(ext) missing from the bundled Fixtures folder"
        )
    }

    private func makeStores(
        service: FixtureIntelligenceService,
        keyStore: any APIKeyStore = InMemoryAPIKeyStore(key: "sk-test")
    ) throws -> (PipelineStore, JobImportStore) {
        let pipeline = try PipelineStore(container: ProfileStore.container(inMemory: true))
        try pipeline.load()
        let importStore = JobImportStore(
            pipelineStore: pipeline, keyStore: keyStore,
            makeIntelligence: { _ in service }
        )
        return (pipeline, importStore)
    }

    private func createdApplication(of store: JobImportStore) throws -> Application {
        guard case .created(let application) = store.phase else {
            throw JobImportError.requestFailed
        }
        return application
    }

    private static let postingPage = Data(
        """
        <html><head><title>Careers</title></head><body>
        <h1>Platform Engineer</h1>
        <p>Own platform reliability across three product teams.</p>
        </body></html>
        """.utf8)

    @Test("[PIPEBOARD-35] importing a job-posting link creates a draft Application with LLM-structured details")
    func linkImportCreatesDraftApplication() async throws {
        let service = FixtureIntelligenceService.jobDetailsFixture()
        let (pipeline, store) = try makeStores(service: service)
        store.fetchLinkData = { _ in Self.postingPage }
        let link = try #require(URL(string: "https://jobs.example.com/platform-engineer"))

        await store.importPosting(fromLink: link)

        let created = try createdApplication(of: store)
        #expect(created.company == "Summit Labs")
        #expect(created.roleTitle == "Platform Engineer")
        #expect(created.jobDescription.contains("Own platform reliability across three product teams."))
        #expect(created.status == .draft)
        #expect(created.appliedAt == nil, "the draft → applied stamp comes later ([PIPEBOARD-9], [CVEXPORT-10])")
        #expect(created.source == "https://jobs.example.com/platform-engineer", "the pasted link lands in source")
        #expect(created.cvSnapshot == nil, "export stays the only path that attaches a CV")
        #expect(created.cvSelectionRationale == nil)
        #expect(pipeline.applications.map(\.company) == ["Summit Labs"], "the board sees the row without a reload")
        // A fresh context sees the saved row — creation persisted.
        let fresh = ModelContext(pipeline.container)
        let persisted = try #require(try fresh.fetch(FetchDescriptor<Application>()).first)
        #expect(persisted.status == .draft)

        // No dedup: importing the same posting twice is two Applications.
        store.reset()
        await store.importPosting(fromLink: link)
        #expect(pipeline.applications.count == 2)

        // The creation seam still refuses blank fields — [PIPEBOARD-19]'s
        // guarantee lives on here; whitespace-only counts as blank.
        #expect(throws: PipelineStoreError.blankField) {
            try pipeline.createApplication(
                company: "   ", roleTitle: "Engineer", source: nil, notes: "", appliedAt: nil)
        }
    }

    @Test("[PIPEBOARD-36] importing a job-posting PDF file creates a draft Application the same way")
    func fileImportCreatesDraftApplication() async throws {
        let service = FixtureIntelligenceService.jobDetailsFixture()
        let (pipeline, store) = try makeStores(service: service)

        await store.importPosting(fromFile: try fixtureURL("sample-cv", "pdf"))

        let created = try createdApplication(of: store)
        #expect(created.company == "Summit Labs")
        #expect(created.roleTitle == "Platform Engineer")
        #expect(created.status == .draft)
        #expect(created.source == "sample-cv.pdf", "the file door lands the file's name in source")
        #expect(pipeline.applications.count == 1)
        // The extracted file text reached the service as the payload.
        let request = try #require(await service.recordedRequests.first)
        #expect(request.payload.contains("Alex Climber"))
    }

    @Test("[PIPEBOARD-37] a link whose page embeds JobPosting structured data feeds the posting text to the extraction")
    func structuredDataFeedsPostingTextToExtraction() async throws {
        let service = FixtureIntelligenceService.jobDetailsFixture()
        let (_, store) = try makeStores(service: service)
        // The Ashby shape ([PIPEBOARD-28]): an empty JS shell carrying the
        // posting as ld+json.
        store.fetchLinkData = { _ in
            Data(
                """
                <html><head><title>Careers</title>
                <script type="application/ld+json">{"@type":"JobPosting",\
                "title":"Platform Engineer",\
                "hiringOrganization":{"@type":"Organization","name":"Summit Labs"},\
                "description":"<h1>About</h1><p>Own platform reliability across three product teams.</p>"}</script>
                </head><body><div id="root">chrome that must not travel</div></body></html>
                """.utf8)
        }

        await store.importPosting(
            fromLink: try #require(URL(string: "https://jobs.example.com/platform-engineer")))

        let request = try #require(await service.recordedRequests.first)
        #expect(request.payload.contains("Own platform reliability across three product teams."))
        #expect(request.payload.contains("Platform Engineer"))
        #expect(request.payload.contains("Summit Labs"))
        #expect(!request.payload.contains("chrome that must not travel"), "the posting, not the page shell")
        #expect(!request.payload.contains("@type"), "the JSON wrapper never leaks into the payload")
    }

    @Test("[PIPEBOARD-38] a failed job-posting import creates no Application")
    func failedImportCreatesNoApplication() async throws {
        let link = try #require(URL(string: "https://jobs.example.com/gone"))

        // The link cannot be fetched.
        do {
            let (pipeline, store) = try makeStores(service: FixtureIntelligenceService.jobDetailsFixture())
            store.fetchLinkData = { _ in throw URLError(.notConnectedToInternet) }
            await store.importPosting(fromLink: link)
            #expect(store.phase == .failed(.fetchFailed))
            #expect(pipeline.applications.isEmpty)
        }

        // The page fetches but its text extracts to nothing.
        do {
            let (pipeline, store) = try makeStores(service: FixtureIntelligenceService.jobDetailsFixture())
            store.fetchLinkData = { _ in Data("<html><body></body></html>".utf8) }
            await store.importPosting(fromLink: link)
            #expect(store.phase == .failed(.noExtractableText))
            #expect(pipeline.applications.isEmpty)
        }

        // A file with no extractable text (an image-only PDF).
        do {
            let (pipeline, store) = try makeStores(service: FixtureIntelligenceService.jobDetailsFixture())
            await store.importPosting(fromFile: try fixtureURL("image-only", "pdf"))
            #expect(store.phase == .failed(.noExtractableText))
            #expect(pipeline.applications.isEmpty)
        }

        // No API key: refused before any fetch or service call (the
        // [TAILOR-4] stance).
        do {
            let service = FixtureIntelligenceService.jobDetailsFixture()
            var fetchCount = 0
            let (pipeline, store) = try makeStores(service: service, keyStore: InMemoryAPIKeyStore())
            store.fetchLinkData = { _ in
                fetchCount += 1
                return Self.postingPage
            }
            await store.importPosting(fromLink: link)
            #expect(store.phase == .failed(.apiKeyRequired))
            #expect(fetchCount == 0, "refused before any fetch")
            #expect(await service.recordedRequests.isEmpty, "refused before any service call")
            #expect(pipeline.applications.isEmpty)
        }

        // A link that is not http(s) never reaches the store — the sheet's
        // pure helper refuses it.
        #expect(JobImportSheet.postingURL(from: "not a url") == nil)
        #expect(JobImportSheet.postingURL(from: "ftp://jobs.example.com/role") == nil)
        #expect(JobImportSheet.postingURL(from: "  https://jobs.example.com/role  ") != nil)
    }

    @Test("[PIPEBOARD-39] an invalid extraction response gets exactly one repair request")
    func invalidResponseGetsExactlyOneRepair() async throws {
        let valid = try Data(contentsOf: fixtureURL("job-details-result", "json"))
        let invalid = Data(#"{"company":""}"#.utf8)
        let link = try #require(URL(string: "https://jobs.example.com/platform-engineer"))

        // Invalid then valid: two requests, never three, and the repair
        // carries the failure and the original payload.
        do {
            let service = FixtureIntelligenceService(returning: [invalid, valid])
            let (pipeline, store) = try makeStores(service: service)
            store.fetchLinkData = { _ in Self.postingPage }
            await store.importPosting(fromLink: link)
            _ = try createdApplication(of: store)
            let requests = await service.recordedRequests
            #expect(requests.count == 2)
            let repair = try #require(requests.last)
            #expect(repair.payload.contains("failed validation"))
            #expect(repair.payload.contains("Own platform reliability across three product teams."))
            #expect(pipeline.applications.count == 1)
        }

        // A repair response failing validation fails the import — nothing
        // created, no third request.
        do {
            let service = FixtureIntelligenceService(returning: [invalid, invalid])
            let (pipeline, store) = try makeStores(service: service)
            store.fetchLinkData = { _ in Self.postingPage }
            await store.importPosting(fromLink: link)
            #expect(store.phase == .failed(.resultInvalid))
            #expect(await service.recordedRequests.count == 2, "never a third request")
            #expect(pipeline.applications.isEmpty)
        }
    }

    @Test("[PIPEBOARD-40] the extraction request carries the versioned job-details prompt")
    func requestCarriesVersionedPrompt() async throws {
        let service = FixtureIntelligenceService.jobDetailsFixture()
        let (_, store) = try makeStores(service: service)
        store.fetchLinkData = { _ in Self.postingPage }

        await store.importPosting(
            fromLink: try #require(URL(string: "https://jobs.example.com/platform-engineer")))

        let request = try #require(await service.recordedRequests.first)
        #expect(request.prompt == (try JobDetailsPrompt.text(from: .main)))
        #expect(request.prompt.contains("# job-details — v"), "versioned on disk, never inline")
        #expect(request.payload.contains("Own platform reliability across three product teams."))
    }

    @Test("[PIPEBOARD-41] the import surface opens from the empty state and the shell toolbar")
    func importSurfaceRendersFromBothHosts() throws {
        // Render-smoke only, the retired [PIPEBOARD-20]/[PIPEBOARD-34]
        // stance: chrome and sheet presentation are on the visual-verify
        // list.
        let emptyStore = try PipelineStore(container: ProfileStore.container(inMemory: true))
        try emptyStore.load()
        let emptyRoot = ImageRenderer(
            content: PipelineRootView(store: emptyStore).frame(width: 800, height: 500))
        #expect(emptyRoot.nsImage != nil, "the empty state renders with its hero action")

        let populatedStore = try PipelineStore(container: ProfileStore.container(inMemory: true))
        let context = ModelContext(populatedStore.container)
        context.insert(
            Application(
                company: "Summit Labs", roleTitle: "Engineer", jobDescription: "JD",
                status: .applied, appliedAt: .now))
        try context.save()
        try populatedStore.load()
        let populatedRoot = ImageRenderer(
            content: PipelineRootView(store: populatedStore).frame(width: 800, height: 500))
        #expect(populatedRoot.nsImage != nil, "the shell renders with its hero toolbar action")

        let sheet = ImageRenderer(
            content: JobImportSheet(
                pipelineStore: emptyStore,
                keyStore: InMemoryAPIKeyStore(key: "sk-test"),
                makeIntelligence: { _ in FixtureIntelligenceService.jobDetailsFixture() }
            ).frame(width: 520, height: 420))
        #expect(sheet.nsImage != nil, "the import sheet renders")
    }

    @Test("[PIPEBOARD-42] Create CV on a snapshot-less application presents tailoring against its stored job description")
    func createCVOfferGatesOnSnapshotAndJobDescription() throws {
        // The offer decision is the measurable clause — a pure helper.
        #expect(ApplicationDetailView.offersCreateCV(cvSnapshot: nil, jobDescription: "Own it."))
        #expect(
            !ApplicationDetailView.offersCreateCV(cvSnapshot: Data([1]), jobDescription: "Own it."),
            "the snapshot is written once — no re-tailor offer")
        #expect(
            !ApplicationDetailView.offersCreateCV(cvSnapshot: nil, jobDescription: ""),
            "nothing to tailor against")
        #expect(
            !ApplicationDetailView.offersCreateCV(cvSnapshot: nil, jobDescription: " \n"),
            "whitespace-only counts as empty")

        // The detail hosting the affordance renders; button prominence and
        // the tailor presentation are visual-verify.
        let store = try PipelineStore(container: ProfileStore.container(inMemory: true))
        let application = Application(
            company: "Summit Labs", roleTitle: "Platform Engineer",
            jobDescription: "Own platform reliability.", status: .draft
        )
        let detail = ImageRenderer(
            content: ApplicationDetailView(
                store: store, application: application, onCreateCV: {}
            ).frame(width: 320, height: 560))
        #expect(detail.nsImage != nil, "the detail renders with its Create CV affordance")
    }
}

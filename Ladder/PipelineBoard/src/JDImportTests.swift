import Foundation
import SwiftData
import Testing

@testable import Ladder

/// Fixture files load from the app bundle's Fixtures folder (tests run in
/// the app host). The sample-cv fixtures double as JD files here — the
/// import never inspects what the text says, only that it extracts.
@MainActor
struct JDImportTests {
    private func fixtureURL(_ name: String, _ ext: String) throws -> URL {
        try #require(
            Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Fixtures"),
            "\(name).\(ext) missing from the bundled Fixtures folder"
        )
    }

    private func makeStore(existingJD: String = "") throws -> (PipelineStore, Application) {
        let container = try ProfileStore.container(inMemory: true)
        let context = ModelContext(container)
        context.insert(
            Application(
                company: "Summit Labs", roleTitle: "Engineer", jobDescription: existingJD,
                status: .applied, appliedAt: .now))
        try context.save()
        let store = PipelineStore(container: container)
        try store.load()
        return (store, try #require(store.applications.first))
    }

    @Test("[PIPEBOARD-22] importing a PDF job description file replaces the Application's job description with its extracted text")
    func pdfImportReplacesJobDescription() throws {
        let (store, application) = try makeStore(existingJD: "the old JD")

        try store.importJobDescription(from: fixtureURL("sample-cv", "pdf"), into: application)

        #expect(application.jobDescription.contains("Alex Climber"))
        #expect(!application.jobDescription.contains("the old JD"), "replaced, not appended")
    }

    @Test("[PIPEBOARD-23] importing a docx job description file replaces the Application's job description with its extracted text")
    func docxImportReplacesJobDescription() throws {
        let (store, application) = try makeStore(existingJD: "the old JD")

        try store.importJobDescription(from: fixtureURL("sample-cv", "docx"), into: application)

        #expect(application.jobDescription.contains("Alex Climber"))
        #expect(!application.jobDescription.contains("the old JD"), "replaced, not appended")
    }

    @Test("[PIPEBOARD-24] a failed job-description import leaves the job description unchanged")
    func failedImportLeavesJobDescriptionUnchanged() throws {
        let (store, application) = try makeStore(existingJD: "the old JD")

        // An image-only PDF extracts no text.
        #expect(throws: TextExtractionError.noExtractableText) {
            try store.importJobDescription(
                from: try fixtureURL("image-only", "pdf"), into: application)
        }
        #expect(application.jobDescription == "the old JD")

        // Neither PDF nor docx.
        let textFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("jd-\(UUID().uuidString).txt")
        try "Plain text JD".write(to: textFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: textFile) }
        #expect(throws: TextExtractionError.unsupportedFileType) {
            try store.importJobDescription(from: textFile, into: application)
        }
        #expect(application.jobDescription == "the old JD")
    }

    @Test("[PIPEBOARD-26] importing a job description link replaces the Application's job description with the page's extracted text")
    func linkImportReplacesJobDescription() async throws {
        let (store, application) = try makeStore(existingJD: "the old JD")
        store.fetchLinkData = { _ in
            Data(
                """
                <html><head><title>Careers</title></head><body>
                <h1>Platform Engineer</h1>
                <p>Own platform reliability across three product teams.</p>
                </body></html>
                """.utf8)
        }

        try await store.importJobDescription(
            fromLink: try #require(URL(string: "https://jobs.example.com/platform-engineer")),
            into: application)

        #expect(application.jobDescription.contains("Own platform reliability across three product teams."))
        #expect(!application.jobDescription.contains("<p>"), "text, not markup")
        #expect(!application.jobDescription.contains("the old JD"), "replaced, not appended")
    }

    @Test("[PIPEBOARD-27] importing a job description link that serves a PDF replaces the job description with the PDF's extracted text")
    func linkServingPDFReplacesJobDescription() async throws {
        let (store, application) = try makeStore(existingJD: "the old JD")
        let pdfData = try Data(contentsOf: fixtureURL("sample-cv", "pdf"))
        store.fetchLinkData = { _ in pdfData }

        try await store.importJobDescription(
            fromLink: try #require(URL(string: "https://jobs.example.com/role.pdf")),
            into: application)

        #expect(application.jobDescription.contains("Alex Climber"))
        #expect(!application.jobDescription.contains("the old JD"), "replaced, not appended")
    }

    @Test("[PIPEBOARD-24] a failed link import leaves the job description unchanged")
    func failedLinkImportLeavesJobDescriptionUnchanged() async throws {
        let (store, application) = try makeStore(existingJD: "the old JD")
        let link = try #require(URL(string: "https://jobs.example.com/gone"))

        // The link cannot be fetched.
        store.fetchLinkData = { _ in throw URLError(.notConnectedToInternet) }
        await #expect(throws: (any Error).self) {
            try await store.importJobDescription(fromLink: link, into: application)
        }
        #expect(application.jobDescription == "the old JD")

        // The page fetches but its text extracts to nothing.
        store.fetchLinkData = { _ in Data("<html><body></body></html>".utf8) }
        await #expect(throws: TextExtractionError.noExtractableText) {
            try await store.importJobDescription(fromLink: link, into: application)
        }
        #expect(application.jobDescription == "the old JD")
    }

    @Test("[PIPEBOARD-25] a job-description import onto a non-empty job description requires confirmation before replacing it")
    func importOntoNonEmptyJobDescriptionNeedsConfirmation() {
        #expect(ApplicationDetailView.jdImportNeedsConfirmation(existing: "Own platform reliability."))
        #expect(!ApplicationDetailView.jdImportNeedsConfirmation(existing: ""))
        #expect(
            !ApplicationDetailView.jdImportNeedsConfirmation(existing: " \n"),
            "whitespace-only counts as empty — nothing worth protecting")
    }
}

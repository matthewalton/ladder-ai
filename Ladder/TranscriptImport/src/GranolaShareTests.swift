import Foundation
import SwiftData
import Testing

@testable import Ladder

@MainActor
struct GranolaShareTests {
    private func makeStage(scheduledAt: Date? = nil) throws -> (ModelContainer, Stage) {
        let container = try ProfileStore.container(inMemory: true)
        let context = ModelContext(container)
        let stage = Stage(kind: .technical, scheduledAt: scheduledAt)
        context.insert(stage)
        try context.save()
        return (container, stage)
    }

    @Test("[TRANSCRIPT-22] the shared document's notes render as the notes overview text")
    func notesTreeFlattens() throws {
        let document = try GranolaSharePayload.parse(html: granolaSharePageHTML())
        #expect(
            document.notesText == granolaExpectedNotes,
            "headings as ## lines, bullets as - lines indented by nesting; the dead transcript-link line is dropped")
    }

    @Test("[TRANSCRIPT-25] a link import's fallback recorded date is the shared document's created date")
    func attachFallsBackToCreatedDate() async throws {
        let (container, stage) = try makeStage()
        let store = GranolaNotesStore(container: container, fetcher: FixtureShareFetcher())
        let createdAt = try #require(
            ISO8601DateFormatter.granolaPayload.date(from: "2026-07-16T13:28:56.612Z"))

        let transcript = try await store.attachNotes(
            fromLinkText: granolaShareURLText, to: stage,
            importedAt: Date(timeIntervalSince1970: 1_772_000_000))
        #expect(transcript.recordedAt == createdAt, "the call's actual moment, not the import moment")
    }

    @Test("[TRANSCRIPT-20] the imported transcript's recorded date takes the Stage's scheduled date")
    func attachTakesScheduledDate() async throws {
        let scheduledAt = Date(timeIntervalSince1970: 1_771_000_000)
        let (container, stage) = try makeStage(scheduledAt: scheduledAt)
        let store = GranolaNotesStore(container: container, fetcher: FixtureShareFetcher())

        let transcript = try await store.attachNotes(
            fromLinkText: granolaShareURLText, to: stage,
            importedAt: Date(timeIntervalSince1970: 1_772_000_000))
        #expect(transcript.recordedAt == scheduledAt, "scheduled beats the document's created date")
    }

    @Test("[TRANSCRIPT-26] a share-link fetch failure ends the import in a refused state naming the reason")
    func fetchFailureRefuses() async throws {
        let (container, stage) = try makeStage()

        let offline = GranolaNotesStore(container: container, fetcher: FailingShareFetcher())
        await #expect(throws: GranolaShareError.fetchFailed) {
            _ = try await offline.attachNotes(
                fromLinkText: granolaShareURLText, to: stage,
                importedAt: Date(timeIntervalSince1970: 1_772_000_000))
        }

        let notAShare = GranolaNotesStore(
            container: container,
            fetcher: FixtureShareFetcher(html: "<html><body>Nothing embedded here</body></html>"))
        await #expect(throws: GranolaShareError.noSharedDocument) {
            _ = try await notAShare.attachNotes(
                fromLinkText: granolaShareURLText, to: stage,
                importedAt: Date(timeIntervalSince1970: 1_772_000_000))
        }
        #expect(try ModelContext(container).fetch(FetchDescriptor<Transcript>()).isEmpty, "nothing is written")
    }

    @Test("[TRANSCRIPT-31] a URL that is not a Granola share link is refused without a request")
    func nonGranolaURLRefusedBeforeAnyRequest() async throws {
        let (container, stage) = try makeStage()
        let spy = SpyShareFetcher()
        let store = GranolaNotesStore(container: container, fetcher: spy)

        for text in [
            "https://example.com/t/abc123",
            "https://notes.granola.ai/other/abc",
            "not a url at all",
            "Me: a pasted transcript is not a link either",
        ] {
            await #expect(throws: GranolaShareError.notAShareLink, "\(text)") {
                _ = try await store.attachNotes(
                    fromLinkText: text, to: stage,
                    importedAt: Date(timeIntervalSince1970: 1_772_000_000))
            }
        }
        #expect(spy.requestCount == 0, "refused before any network call")
        #expect(GranolaSharePayload.shareLink(in: "  \(granolaShareURLText)  ") != nil, "the real link still opens the door")
    }
}

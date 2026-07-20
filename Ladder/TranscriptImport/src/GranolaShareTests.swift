import Foundation
import SwiftData
import Testing

@testable import Ladder

// MARK: - Fixture share pages

/// Builds a Granola share page the way Next.js emits it: the payload JSON
/// JS-escaped inside `self.__next_f.push([1,"…"])` chunks, split across two
/// script tags to prove the parser concatenates before reading.
private func sharePageHTML(documentTranscript: String) -> String {
    let payload = """
        {"documentPanel":{"document":{"id":"d6baa78f","title":"Interview with Watershed",\
        "created_at":"2026-07-16T13:28:56.612Z","ydoc_version":null},\
        "panel":{"title":"Interview with Watershed","content":{"type":"doc","content":[\
        {"type":"heading","attrs":{"level":1},"content":[{"type":"text","text":"Interview Format and Setup"}]},\
        {"type":"bulletList","content":[\
        {"type":"listItem","content":[{"type":"paragraph","content":[{"type":"text","text":"Technical coding challenge via CodeSignal"}]}]},\
        {"type":"listItem","content":[{"type":"paragraph","content":[{"type":"text","text":"Preferred language: TypeScript"}]},\
        {"type":"bulletList","content":[{"type":"listItem","content":[{"type":"paragraph","content":[{"type":"text","text":"TSC type-checking active"}]}]}]}]}]},\
        {"type":"paragraph","content":[{"type":"text","text":"Chat with meeting transcript: "},{"type":"text","text":"https://notes.granola.ai/t/707b6902"}]}]}}},\
        "documentLists":[],"documentTranscript":\(documentTranscript)}
        """
    let escaped = payload
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
    let middle = escaped.index(escaped.startIndex, offsetBy: escaped.count / 2)
    // Never split inside an escape pair.
    let split = escaped[middle] == "\\" ? escaped.index(after: middle) : middle
    let first = String(escaped[..<split])
    let second = String(escaped[split...])
    return """
        <!DOCTYPE html><html><head><title>Granola</title></head><body>
        <script>self.__next_f.push([1,"a:[\\"$\\",\\"div\\",null,{"])</script>
        <script>self.__next_f.push([1,"\(first)"])</script>
        <script>self.__next_f.push([1,"\(second)"])</script>
        </body></html>
        """
}

private let transcriptJSON = """
    [{"text":"Thanks for making time today.","source":"microphone","start_timestamp":5,"end_timestamp":9},\
    {"text":"Of course - shall we dive in?","source":"system","start_timestamp":10},\
    {"text":"Ready when you are.","source":"microphone"}]
    """

private struct FixtureShareFetcher: GranolaShareFetching {
    var html: String
    func html(from url: URL) async throws -> String { html }
}

private struct FailingShareFetcher: GranolaShareFetching {
    func html(from url: URL) async throws -> String {
        throw URLError(.notConnectedToInternet)
    }
}

private let shareURLText = "https://notes.granola.ai/t/d6baa78f-1080-40c2-a396-bccbfd7b5732-008umkv4"

// MARK: - Tests

@MainActor
struct GranolaShareTests {
    private func makeStage() throws -> (ModelContainer, Stage) {
        let container = try ProfileStore.container(inMemory: true)
        let context = ModelContext(container)
        let stage = Stage(kind: .technical)
        context.insert(stage)
        try context.save()
        return (container, stage)
    }

    @Test("[TRANSCRIPT-21] a pasted Granola share link fetches the shared document into the preview")
    func shareLinkFetchesIntoPreview() async throws {
        let (container, stage) = try makeStage()
        let store = TranscriptImportStore(
            container: container,
            fetcher: FixtureShareFetcher(html: sharePageHTML(documentTranscript: transcriptJSON)))

        let url = try #require(GranolaSharePayload.shareLink(in: "  \(shareURLText)  "))
        #expect(url.host() == "notes.granola.ai")
        let imported = try await store.fetchShareImport(from: url, for: stage)
        #expect(imported.preview.segments.count == 3)
        #expect(!imported.preview.replacesExisting)

        #expect(
            GranolaSharePayload.shareLink(in: "Me: not a link\n\(shareURLText)") == nil,
            "only a lone URL opens the door — a transcript paste containing a link is a paste")
    }

    @Test("[TRANSCRIPT-22] the shared document's notes render as the notes overview text")
    func notesTreeFlattens() throws {
        let document = try GranolaSharePayload.parse(
            html: sharePageHTML(documentTranscript: "null"))
        #expect(
            document.notesText == """
                ## Interview Format and Setup
                - Technical coding challenge via CodeSignal
                - Preferred language: TypeScript
                  - TSC type-checking active
                """,
            "headings as ## lines, bullets as - lines indented by nesting")
    }

    @Test("[TRANSCRIPT-23] a shared transcript's microphone source attributes to me and any other source to them")
    func sharedTranscriptMapsStreamIdentity() throws {
        let document = try GranolaSharePayload.parse(
            html: sharePageHTML(documentTranscript: transcriptJSON))
        let segments = try #require(document.segments)
        #expect(segments.map(\.speaker) == [.me, .them, .me])
        #expect(segments[0].text == "Thanks for making time today.")
        #expect(segments[0].tStart == 5)
        #expect(segments[0].tEnd == 9)
        #expect(segments[1].tStart == 10)
        #expect(segments[1].tEnd == nil)
        #expect(segments[2].tStart == nil, "timestamps come along only when the payload carries them")
    }

    @Test("[TRANSCRIPT-24] a share link carrying no transcript produces a preview with no segments")
    func transcriptlessLinkImportsNotesOnly() async throws {
        let (container, stage) = try makeStage()
        let store = TranscriptImportStore(
            container: container,
            fetcher: FixtureShareFetcher(html: sharePageHTML(documentTranscript: "null")))

        let imported = try await store.fetchShareImport(
            from: try #require(URL(string: shareURLText)), for: stage)
        #expect(imported.preview.segments.isEmpty)
        #expect(!imported.hasTranscript)
        #expect(imported.notesOverview.contains("Interview Format and Setup"))

        let transcript = try store.confirm(
            imported.preview, notesOverview: imported.notesOverview,
            onto: stage, importedAt: Date(timeIntervalSince1970: 1_772_000_000))
        #expect(transcript.segments.isEmpty, "a notes-only Transcript attaches with zero segments")
        #expect(transcript.notesSummary?.contains("CodeSignal") == true)
    }

    @Test("[TRANSCRIPT-25] a link import's fallback recorded date is the shared document's created date")
    func linkImportFallsBackToCreatedDate() async throws {
        let (container, stage) = try makeStage()
        let store = TranscriptImportStore(
            container: container,
            fetcher: FixtureShareFetcher(html: sharePageHTML(documentTranscript: transcriptJSON)))
        let createdAt = try #require(
            ISO8601DateFormatter.granolaPayload.date(from: "2026-07-16T13:28:56.612Z"))

        let imported = try await store.fetchShareImport(
            from: try #require(URL(string: shareURLText)), for: stage)
        #expect(imported.suggestedImportDate == createdAt)

        let transcript = try store.confirm(
            imported.preview, onto: stage,
            importedAt: imported.suggestedImportDate ?? Date(timeIntervalSince1970: 0))
        #expect(transcript.recordedAt == createdAt, "the call's actual moment, not the import moment")
    }

    @Test("[TRANSCRIPT-26] a share-link fetch failure ends the import in a refused state naming the reason")
    func fetchFailureRefuses() async throws {
        let (container, stage) = try makeStage()
        let url = try #require(URL(string: shareURLText))

        let offline = TranscriptImportStore(container: container, fetcher: FailingShareFetcher())
        await #expect(throws: GranolaShareError.fetchFailed) {
            _ = try await offline.fetchShareImport(from: url, for: stage)
        }

        let notAShare = TranscriptImportStore(
            container: container,
            fetcher: FixtureShareFetcher(html: "<html><body>Nothing embedded here</body></html>"))
        await #expect(throws: GranolaShareError.noSharedDocument) {
            _ = try await notAShare.fetchShareImport(from: url, for: stage)
        }
        #expect(try ModelContext(container).fetch(FetchDescriptor<Transcript>()).isEmpty, "nothing is written")
    }

    @Test("[TRANSCRIPT-27] a pasted URL that is not a Granola share link is refused as unlabeled text")
    func nonGranolaURLIsRefused() throws {
        #expect(GranolaSharePayload.shareLink(in: "https://example.com/t/abc123") == nil)
        #expect(GranolaSharePayload.shareLink(in: "https://notes.granola.ai/other/abc") == nil, "only share paths")

        // Falls through to the paste parser, which refuses it as unlabeled.
        #expect(throws: TranscriptParseError.noSpeakerLabels) {
            try TranscriptParser.parse("https://example.com/t/abc123")
        }
    }
}

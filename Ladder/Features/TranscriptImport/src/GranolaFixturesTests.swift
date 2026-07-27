import Foundation

@testable import Ladder

// Shared fixtures for the slice's tests. The file's *Tests.swift name
// routes it to the test target; it defines no tests itself.

/// Builds a Granola share page the way Next.js emits it: the payload JSON
/// JS-escaped inside `self.__next_f.push([1,"…"])` chunks, split across two
/// script tags to prove the parser concatenates before reading.
func granolaSharePageHTML() -> String {
    let payload = """
        {"documentPanel":{"document":{"id":"d6baa78f","title":"Interview with Watershed",\
        "created_at":"2026-07-16T13:28:56.612Z","ydoc_version":null},\
        "panel":{"title":"Summary","content":{"type":"doc","content":[\
        {"type":"heading","attrs":{"level":1},"content":[{"type":"text","text":"Interview Format and Setup"}]},\
        {"type":"bulletList","content":[\
        {"type":"listItem","content":[{"type":"paragraph","content":[{"type":"text","text":"Technical coding challenge via CodeSignal"}]}]},\
        {"type":"listItem","content":[{"type":"paragraph","content":[{"type":"text","text":"Preferred language: TypeScript"}]},\
        {"type":"bulletList","content":[{"type":"listItem","content":[{"type":"paragraph","content":[{"type":"text","text":"TSC type-checking active"}]}]}]}]}]},\
        {"type":"paragraph","content":[{"type":"text","text":"Chat with meeting transcript: "},{"type":"text","text":"https://notes.granola.ai/t/707b6902"}]}]}}},\
        "documentLists":[],"documentTranscript":null}
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

let granolaShareURLText = "https://notes.granola.ai/t/d6baa78f-1080-40c2-a396-bccbfd7b5732-008umkv4"

/// The fixture notes the page above flattens to.
let granolaExpectedNotes = """
    ## Interview Format and Setup
    - Technical coding challenge via CodeSignal
    - Preferred language: TypeScript
      - TSC type-checking active
    """

struct FixtureShareFetcher: GranolaShareFetching {
    var html: String = granolaSharePageHTML()
    func html(from url: URL) async throws -> String { html }
}

struct FailingShareFetcher: GranolaShareFetching {
    func html(from url: URL) async throws -> String {
        throw URLError(.notConnectedToInternet)
    }
}

/// Records whether any request was ever made ([TRANSCRIPT-31]).
final class SpyShareFetcher: GranolaShareFetching, @unchecked Sendable {
    private(set) var requestCount = 0
    func html(from url: URL) async throws -> String {
        requestCount += 1
        return granolaSharePageHTML()
    }
}

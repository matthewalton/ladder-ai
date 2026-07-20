import Foundation
import SwiftData

/// Attach / replace / remove Granola notes on a Stage — the one-step flow
/// (decisions/0007). Fetching is behind the `GranolaShareFetching` seam;
/// only `attachNotes` and `removeNotes` write.
@MainActor
@Observable
final class GranolaNotesStore {
    private let context: ModelContext
    private let fetcher: GranolaShareFetching

    init(container: ModelContainer, fetcher: GranolaShareFetching = LiveGranolaShareFetcher()) {
        self.context = ModelContext(container)
        self.fetcher = fetcher
    }

    /// Validates, fetches, and attaches in one step. Replaces any existing
    /// notes ([TRANSCRIPT-29]); throws before any request when the text is
    /// not a share link ([TRANSCRIPT-31]).
    @discardableResult
    func attachNotes(fromLinkText text: String, to stage: Stage, importedAt: Date) async throws -> Transcript {
        guard let url = GranolaSharePayload.shareLink(in: text) else {
            throw GranolaShareError.notAShareLink
        }
        let html: String
        do {
            html = try await fetcher.html(from: url)
        } catch {
            throw GranolaShareError.fetchFailed
        }
        let document = try GranolaSharePayload.parse(html: html)
        let notes = document.notesText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !notes.isEmpty else { throw GranolaShareError.noSharedDocument }

        let context = stage.modelContext ?? self.context
        if let existing = stage.transcript {
            context.delete(existing)
        }
        let transcript = Transcript(
            // The call's moment: scheduled date, else the document's created
            // date, else the explicit import moment ([TRANSCRIPT-20/25]).
            recordedAt: stage.scheduledAt ?? document.createdAt ?? importedAt,
            notesSummary: notes
        )
        context.insert(transcript)
        stage.transcript = transcript
        try context.save()
        return transcript
    }

    /// Deletes the notes record and clears the link ([TRANSCRIPT-30]).
    func removeNotes(from stage: Stage) throws {
        guard let transcript = stage.transcript else { return }
        let context = stage.modelContext ?? self.context
        stage.transcript = nil
        context.delete(transcript)
        try context.save()
    }
}

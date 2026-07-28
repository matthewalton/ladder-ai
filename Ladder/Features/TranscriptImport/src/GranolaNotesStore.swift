import Foundation
import SwiftData

@MainActor
@Observable
final class GranolaNotesStore {
    private let context: ModelContext
    private let fetcher: GranolaShareFetching

    init(container: ModelContainer, fetcher: GranolaShareFetching = LiveGranolaShareFetcher()) {
        self.context = ModelContext(container)
        self.fetcher = fetcher
    }

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
            recordedAt: stage.scheduledAt ?? document.createdAt ?? importedAt,
            notesSummary: notes
        )
        context.insert(transcript)
        stage.transcript = transcript
        try context.save()
        return transcript
    }

    func removeNotes(from stage: Stage) throws {
        guard let transcript = stage.transcript else { return }
        let context = stage.modelContext ?? self.context
        stage.transcript = nil
        context.delete(transcript)
        try context.save()
    }
}

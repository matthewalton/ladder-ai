import Foundation
import SwiftData

/// The parsed-but-unwritten result shown before confirmation
/// (decisions/0004). Confirming attaches; cancelling writes nothing.
struct TranscriptImportPreview: Equatable {
    var segments: [Segment]
    /// True exactly when the target Stage already has a transcript, so the
    /// sheet can warn before the confirm (decisions/0003).
    var replacesExisting: Bool
}

enum TranscriptFileError: Error, Equatable {
    /// Text is the only door (ADR 0002) — carries the offending extension.
    case unsupportedFileType(String)
}

/// What a share-link fetch hands the sheet ([TRANSCRIPT-21]): the preview,
/// plus the notes overview and the call's created date to prefill.
struct ShareImport {
    var preview: TranscriptImportPreview
    var notesOverview: String
    /// The shared document's created date — the [TRANSCRIPT-25] fallback.
    var suggestedImportDate: Date?
    var hasTranscript: Bool
}

/// Parse → preview → confirm. Parsing is pure; only `confirm` writes.
@MainActor
@Observable
final class TranscriptImportStore {
    private let context: ModelContext
    private let fetcher: GranolaShareFetching

    init(container: ModelContainer, fetcher: GranolaShareFetching = LiveGranolaShareFetcher()) {
        self.context = ModelContext(container)
        self.fetcher = fetcher
    }

    /// The URL door (decisions/0006): fetch the share page and parse its
    /// embedded payload into the same preview the other doors feed.
    func fetchShareImport(from url: URL, for stage: Stage) async throws -> ShareImport {
        let html: String
        do {
            html = try await fetcher.html(from: url)
        } catch {
            throw GranolaShareError.fetchFailed
        }
        let document = try GranolaSharePayload.parse(html: html)
        return ShareImport(
            preview: TranscriptImportPreview(
                segments: document.segments ?? [],
                replacesExisting: stage.transcript != nil
            ),
            notesOverview: document.notesText,
            suggestedImportDate: document.createdAt,
            hasTranscript: document.segments != nil
        )
    }

    /// Derives the preview for pasted or file-read text. Throws
    /// `TranscriptParseError` when nothing can be attributed.
    func preview(of text: String, for stage: Stage) throws -> TranscriptImportPreview {
        TranscriptImportPreview(
            segments: try TranscriptParser.parse(text),
            replacesExisting: stage.transcript != nil
        )
    }

    /// The importable extensions, matched case-insensitively ([TRANSCRIPT-11]).
    static let importableExtensions: Set<String> = ["txt", "md"]

    /// The file door: reads a dropped .txt/.md file's text into the same
    /// parse as a paste — one pipeline, two doors.
    func preview(ofFileAt url: URL, for stage: Stage) throws -> TranscriptImportPreview {
        let ext = url.pathExtension.lowercased()
        guard Self.importableExtensions.contains(ext) else {
            throw TranscriptFileError.unsupportedFileType(ext)
        }
        return try preview(of: String(contentsOf: url, encoding: .utf8), for: stage)
    }

    /// Attaches the previewed transcript, replacing any existing one — the
    /// old Transcript is deleted from the store, never orphaned
    /// (decisions/0003). `recordedAt` is the Stage's scheduled date when set,
    /// else the caller-supplied import moment ([TRANSCRIPT-20]).
    @discardableResult
    func confirm(
        _ preview: TranscriptImportPreview,
        notesOverview: String? = nil,
        onto stage: Stage,
        importedAt: Date
    ) throws -> Transcript {
        let context = stage.modelContext ?? self.context
        if let existing = stage.transcript {
            context.delete(existing)
        }
        let trimmedNotes = notesOverview?.trimmingCharacters(in: .whitespacesAndNewlines)
        let transcript = Transcript(
            recordedAt: stage.scheduledAt ?? importedAt,
            durationSec: TranscriptParser.duration(of: preview.segments),
            notesSummary: (trimmedNotes?.isEmpty ?? true) ? nil : trimmedNotes,
            segments: preview.segments
        )
        context.insert(transcript)
        stage.transcript = transcript
        try context.save()
        return transcript
    }
}

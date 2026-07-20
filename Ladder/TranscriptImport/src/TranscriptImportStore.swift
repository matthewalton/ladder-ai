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

/// Parse → preview → confirm. Parsing is pure; only `confirm` writes.
@MainActor
@Observable
final class TranscriptImportStore {
    private let context: ModelContext

    init(container: ModelContainer) {
        self.context = ModelContext(container)
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

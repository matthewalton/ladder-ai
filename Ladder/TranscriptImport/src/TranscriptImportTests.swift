import Foundation
import SwiftData
import Testing

@testable import Ladder

@MainActor
struct TranscriptImportTests {
    @Test("[TRANSCRIPT-1] a transcript confirmed onto a Stage is still on the Stage after the app relaunches")
    func confirmedTranscriptSurvivesRelaunch() throws {
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }
        let granola = """
            Me: Thanks for making time today.
            Jane Doe: Of course — shall we dive in?
            """

        do {
            let container = try ProfileStore.container(at: url)
            let context = ModelContext(container)
            let application = Application(
                company: "Summit Labs", roleTitle: "Platform Engineer",
                jobDescription: "Own platform reliability.", status: .active)
            context.insert(application)
            let stage = Stage(kind: .technical)
            context.insert(stage)
            stage.application = application
            try context.save()

            let store = TranscriptImportStore(container: container)
            let preview = try store.preview(of: granola, for: stage)
            try store.confirm(
                preview, onto: stage,
                importedAt: Date(timeIntervalSince1970: 1_772_000_000))
        }

        let reopened = try ProfileStore.container(at: url)
        let context = ModelContext(reopened)
        let stage = try #require(try context.fetch(FetchDescriptor<Stage>()).first)
        let transcript = try #require(stage.transcript, "the transcript is still on the Stage")
        #expect(transcript.segments.count == 2)
        #expect(transcript.segments.first?.speaker == .me)
        #expect(transcript.segments.first?.text == "Thanks for making time today.")
        #expect(transcript.segments.last?.speaker == .them)
        #expect(transcript.segments.last?.text == "Of course — shall we dive in?")
    }

    @Test("[TRANSCRIPT-2] a fully-populated Transcript round-trips through a store reopen")
    func fullyPopulatedTranscriptRoundTrips() throws {
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }
        let recordedAt = Date(timeIntervalSince1970: 1_771_000_000)
        let segments = [
            Segment(speaker: .me, text: "Thanks for making time.", tStart: 10, tEnd: 14),
            Segment(speaker: .them, text: "Of course.", tStart: 15, tEnd: 17),
        ]

        do {
            let container = try ProfileStore.container(at: url)
            let context = ModelContext(container)
            let application = Application(
                company: "Summit Labs", roleTitle: "Platform Engineer",
                jobDescription: "JD", status: .active)
            context.insert(application)
            let stage = Stage(kind: .technical)
            context.insert(stage)
            stage.application = application
            let transcript = Transcript(
                recordedAt: recordedAt,
                durationSec: 17,
                sourceApp: "zoom.us",
                notesSummary: "Covered the outage story and CI work.",
                segments: segments
            )
            context.insert(transcript)
            stage.transcript = transcript
            try context.save()
        }

        let reopened = try ProfileStore.container(at: url)
        let context = ModelContext(reopened)
        let transcript = try #require(try context.fetch(FetchDescriptor<Transcript>()).first)
        #expect(transcript.recordedAt == recordedAt)
        #expect(transcript.durationSec == 17)
        #expect(transcript.sourceApp == "zoom.us")
        #expect(transcript.notesSummary == "Covered the outage story and CI work.")
        #expect(transcript.segments == segments, "segments round-trip field-for-field")
        #expect(transcript.stage?.kind == .technical)
    }

    @Test("[TRANSCRIPT-3] deleting a Stage deletes its transcript with it")
    func deletingStageCascadesToTranscript() throws {
        let container = try ProfileStore.container(inMemory: true)
        let context = ModelContext(container)
        let application = Application(
            company: "Summit Labs", roleTitle: "Platform Engineer",
            jobDescription: "JD", status: .active)
        context.insert(application)
        let stage = Stage(kind: .screen)
        context.insert(stage)
        stage.application = application
        try context.save()

        let store = TranscriptImportStore(container: container)
        let preview = try store.preview(of: "Me: Hello.", for: stage)
        try store.confirm(preview, onto: stage, importedAt: Date(timeIntervalSince1970: 1_772_000_000))

        context.delete(stage)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<Transcript>()).isEmpty, "no orphaned Transcript survives")
    }

    @Test("[TRANSCRIPT-10] pasting transcript text produces a preview of the parsed segments")
    func pasteProducesPreview() throws {
        let container = try ProfileStore.container(inMemory: true)
        let context = ModelContext(container)
        let stage = Stage(kind: .technical)
        context.insert(stage)
        try context.save()

        let store = TranscriptImportStore(container: container)
        let preview = try store.preview(
            of: "Me (00:05): Shall we start?\nJane: Yes.", for: stage)
        #expect(preview.segments.count == 2)
        #expect(preview.segments.first?.speaker == .me)
        #expect(preview.segments.first?.tStart == 5)
        #expect(preview.segments.last?.speaker == .them)
        #expect(!preview.replacesExisting, "a bare Stage has nothing to replace")
    }

    @Test("[TRANSCRIPT-11] dropping a .txt or .md file produces a preview of the file's parsed segments")
    func droppedFileProducesPreview() throws {
        let container = try ProfileStore.container(inMemory: true)
        let context = ModelContext(container)
        let stage = Stage(kind: .technical)
        context.insert(stage)
        try context.save()
        let store = TranscriptImportStore(container: container)

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("transcript-drop-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        // One pipeline, two doors: the file's text enters the same parse as
        // a paste — and extension matching is case-insensitive.
        for name in ["granola.txt", "granola.md", "granola-upper.TXT"] {
            let url = directory.appendingPathComponent(name)
            try "Me: Hello.\nJane: Hi there.".write(to: url, atomically: true, encoding: .utf8)
            let preview = try store.preview(ofFileAt: url, for: stage)
            #expect(preview.segments.count == 2, "\(name) parses like a paste")
            #expect(preview.segments.first?.speaker == .me)
            #expect(preview.segments.last?.speaker == .them)
        }
    }

    @Test("[TRANSCRIPT-12] a dropped file that is neither .txt nor .md is rejected")
    func nonTextFileIsRejected() throws {
        let container = try ProfileStore.container(inMemory: true)
        let context = ModelContext(container)
        let stage = Stage(kind: .technical)
        context.insert(stage)
        try context.save()
        let store = TranscriptImportStore(container: container)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("transcript-reject-\(UUID().uuidString).pdf")
        try "Me: Text inside, but the extension is the door check.".write(
            to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(throws: TranscriptFileError.unsupportedFileType("pdf")) {
            try store.preview(ofFileAt: url, for: stage)
        }
    }

    @Test("[TRANSCRIPT-13] cancelling the preview leaves the Stage unchanged")
    func cancellingWritesNothing() throws {
        let container = try ProfileStore.container(inMemory: true)
        let context = ModelContext(container)
        let stage = Stage(kind: .technical)
        context.insert(stage)
        try context.save()

        let store = TranscriptImportStore(container: container)
        let importedAt = Date(timeIntervalSince1970: 1_772_000_000)

        // Preview derived, never confirmed — nothing persists.
        _ = try store.preview(of: "Me: Never confirmed.", for: stage)
        #expect(try context.fetch(FetchDescriptor<Transcript>()).isEmpty)
        #expect(stage.transcript == nil)

        // With a transcript in place, an abandoned replacement leaves it as it was.
        let kept = try store.confirm(
            try store.preview(of: "Me: The kept transcript.", for: stage),
            onto: stage, importedAt: importedAt)
        _ = try store.preview(of: "Me: The abandoned replacement.", for: stage)
        #expect(stage.transcript === kept)
        #expect(try context.fetch(FetchDescriptor<Transcript>()).count == 1)
    }

    @Test("[TRANSCRIPT-14] confirming an import onto a Stage with a transcript replaces the existing transcript")
    func confirmingReplacesExistingTranscript() throws {
        let container = try ProfileStore.container(inMemory: true)
        let context = ModelContext(container)
        let stage = Stage(kind: .technical)
        context.insert(stage)
        try context.save()

        let store = TranscriptImportStore(container: container)
        let importedAt = Date(timeIntervalSince1970: 1_772_000_000)
        try store.confirm(
            try store.preview(of: "Me: The first import.", for: stage),
            onto: stage, importedAt: importedAt)
        let replacement = try store.confirm(
            try store.preview(of: "Me: The corrected paste.", for: stage),
            onto: stage, importedAt: importedAt)

        #expect(stage.transcript === replacement)
        let persisted = try context.fetch(FetchDescriptor<Transcript>())
        #expect(persisted.count == 1, "the old Transcript is deleted, not orphaned")
        #expect(persisted.first?.segments.first?.text == "The corrected paste.")
    }

    @Test("[TRANSCRIPT-15] the preview flags when confirming will replace an existing transcript")
    func previewFlagsReplacement() throws {
        let container = try ProfileStore.container(inMemory: true)
        let context = ModelContext(container)
        let stage = Stage(kind: .technical)
        context.insert(stage)
        try context.save()

        let store = TranscriptImportStore(container: container)
        let first = try store.preview(of: "Me: First.", for: stage)
        #expect(!first.replacesExisting)
        try store.confirm(first, onto: stage, importedAt: Date(timeIntervalSince1970: 1_772_000_000))
        let second = try store.preview(of: "Me: Second.", for: stage)
        #expect(second.replacesExisting, "flagged exactly when the Stage already has a transcript")
    }

    @Test("[TRANSCRIPT-16] the imported transcript carries the pasted notes overview")
    func notesOverviewLandsOnTheTranscript() throws {
        let container = try ProfileStore.container(inMemory: true)
        let context = ModelContext(container)
        let stage = Stage(kind: .technical)
        context.insert(stage)
        try context.save()

        let store = TranscriptImportStore(container: container)
        let importedAt = Date(timeIntervalSince1970: 1_772_000_000)
        let overview = "## Summary\n- Strong on the outage story\n- Follow up on system design"
        let withNotes = try store.confirm(
            try store.preview(of: "Me: Hello.", for: stage),
            notesOverview: overview, onto: stage, importedAt: importedAt)
        #expect(withNotes.notesSummary == overview, "stored verbatim")

        let withoutNotes = try store.confirm(
            try store.preview(of: "Me: Replaced.", for: stage),
            notesOverview: "   \n", onto: stage, importedAt: importedAt)
        #expect(withoutNotes.notesSummary == nil, "blank means nil, never an empty string — and replacement swapped the old overview out")
    }

    @Test("[TRANSCRIPT-20] the imported transcript's recorded date takes the Stage's scheduled date")
    func recordedDateTakesScheduledDate() throws {
        let container = try ProfileStore.container(inMemory: true)
        let context = ModelContext(container)
        let scheduledAt = Date(timeIntervalSince1970: 1_771_000_000)
        let importedAt = Date(timeIntervalSince1970: 1_772_000_000)
        let scheduled = Stage(kind: .technical, scheduledAt: scheduledAt)
        let unscheduled = Stage(kind: .screen, sortIndex: 1)
        context.insert(scheduled)
        context.insert(unscheduled)
        try context.save()

        let store = TranscriptImportStore(container: container)
        let onScheduled = try store.confirm(
            try store.preview(of: "Me: Hello.", for: scheduled),
            onto: scheduled, importedAt: importedAt)
        #expect(onScheduled.recordedAt == scheduledAt, "the interview happened at the scheduled moment")

        let onUnscheduled = try store.confirm(
            try store.preview(of: "Me: Hello.", for: unscheduled),
            onto: unscheduled, importedAt: importedAt)
        #expect(onUnscheduled.recordedAt == importedAt, "unscheduled falls back to the explicit import moment")
    }
}

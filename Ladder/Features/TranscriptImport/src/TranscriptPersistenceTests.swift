import Foundation
import SwiftData
import Testing

@testable import Ladder

@MainActor
struct TranscriptPersistenceTests {
    @Test("[TRANSCRIPT-28] notes attached from a Granola link are still on the Stage after the app relaunches")
    func attachedNotesSurviveRelaunch() async throws {
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }

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

            let store = GranolaNotesStore(container: container, fetcher: FixtureShareFetcher())
            try await store.attachNotes(
                fromLinkText: granolaShareURLText, to: stage,
                importedAt: Date(timeIntervalSince1970: 1_772_000_000))
        }

        let reopened = try ProfileStore.container(at: url)
        let context = ModelContext(reopened)
        let stage = try #require(try context.fetch(FetchDescriptor<Stage>()).first)
        let transcript = try #require(stage.transcript, "the notes are still on the Stage")
        #expect(transcript.notesSummary == granolaExpectedNotes)
        #expect(transcript.segments.isEmpty, "a notes import writes no segments (decisions/0007)")
    }

    @Test("[TRANSCRIPT-2] a fully-populated Transcript round-trips through a store reopen")
    func fullyPopulatedTranscriptRoundTrips() throws {
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }
        let recordedAt = Date(timeIntervalSince1970: 1_771_000_000)
        // The model outlives this slice's scope: segments persist faithfully
        // even though a notes import never writes one.
        let segments = [
            Segment(speaker: .me, text: "Thanks for making time.", tStart: 10, tEnd: 14),
            Segment(speaker: .them, text: "Of course.", tStart: 15, tEnd: 17),
        ]

        do {
            let container = try ProfileStore.container(at: url)
            let context = ModelContext(container)
            let stage = Stage(kind: .technical)
            context.insert(stage)
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
    func deletingStageCascadesToTranscript() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let context = ModelContext(container)
        let stage = Stage(kind: .screen)
        context.insert(stage)
        try context.save()

        let store = GranolaNotesStore(container: container, fetcher: FixtureShareFetcher())
        try await store.attachNotes(
            fromLinkText: granolaShareURLText, to: stage,
            importedAt: Date(timeIntervalSince1970: 1_772_000_000))

        context.delete(stage)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<Transcript>()).isEmpty, "no orphaned Transcript survives")
    }

    @Test("[TRANSCRIPT-29] attaching a link onto a Stage that has notes replaces the existing notes")
    func attachingReplacesExistingNotes() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let context = ModelContext(container)
        let stage = Stage(kind: .technical)
        context.insert(stage)
        try context.save()

        let store = GranolaNotesStore(container: container, fetcher: FixtureShareFetcher())
        let importedAt = Date(timeIntervalSince1970: 1_772_000_000)
        let first = try await store.attachNotes(
            fromLinkText: granolaShareURLText, to: stage, importedAt: importedAt)
        let second = try await store.attachNotes(
            fromLinkText: granolaShareURLText, to: stage, importedAt: importedAt)

        #expect(stage.transcript === second)
        #expect(first !== second)
        #expect(
            try context.fetch(FetchDescriptor<Transcript>()).count == 1,
            "the old record is deleted, not orphaned")
    }

    @Test("[TRANSCRIPT-30] removing the notes deletes the stored record")
    func removingNotesDeletesTheRecord() async throws {
        let container = try ProfileStore.container(inMemory: true)
        let context = ModelContext(container)
        let stage = Stage(kind: .technical)
        context.insert(stage)
        try context.save()

        let store = GranolaNotesStore(container: container, fetcher: FixtureShareFetcher())
        try await store.attachNotes(
            fromLinkText: granolaShareURLText, to: stage,
            importedAt: Date(timeIntervalSince1970: 1_772_000_000))
        try store.removeNotes(from: stage)

        #expect(stage.transcript == nil, "the Stage returns to its empty import state")
        #expect(try context.fetch(FetchDescriptor<Transcript>()).isEmpty)

        // Removing when nothing is attached is a quiet no-op.
        try store.removeNotes(from: stage)
    }
}

import Foundation
import SwiftData
import Testing

@testable import Ladder

@MainActor
struct DebriefMigrationTests {
    @Test("[DEBRIEF-4] a Phase 3 Application survives the schema migration with its Stages, notes and CV snapshot intact")
    func phaseThreeStoreSurvivesMigration() throws {
        // The committed fixture store was written by the Phase 3 schema —
        // never regenerate it. Copy it (sidecars too) before opening:
        // migration rewrites the file.
        let fixtureDirectory = try #require(
            Bundle.main.url(forResource: "Phase3Store", withExtension: nil, subdirectory: "Fixtures"),
            "Phase3Store is missing from the bundled Fixtures folder"
        )
        let workDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("phase3-migration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workDirectory) }
        for suffix in ["", "-wal", "-shm"] {
            let name = "phase3.store\(suffix)"
            let source = fixtureDirectory.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: source.path) else { continue }
            try FileManager.default.copyItem(
                at: source, to: workDirectory.appendingPathComponent(name))
        }
        let url = workDirectory.appendingPathComponent("phase3.store")

        let migrated = try ProfileStore.container(at: url)
        let context = ModelContext(migrated)

        let applications = try context.fetch(FetchDescriptor<Application>())
        #expect(applications.count == 1, "every Phase 3 Application survives")
        let application = try #require(applications.first)
        #expect(application.company == "Summit Labs")
        #expect(application.status == .active)
        #expect(application.appliedAt == Date(timeIntervalSince1970: 1_770_100_000))
        #expect(application.source == "Referral — Jamie")
        #expect(application.notes == "Second round rescheduled twice.")
        #expect(
            application.cvSnapshot == Data("phase-3 snapshot: exact bytes are the point".utf8),
            "snapshot bytes are byte-identical through the migration"
        )

        #expect(application.stages.count == 2, "every Stage survives")
        let stages = application.orderedStages
        #expect(stages.map(\.kind) == [.screen, .technical])
        let screen = try #require(stages.first)
        #expect(screen.scheduledAt == Date(timeIntervalSince1970: 1_771_000_000))
        #expect(screen.calendarEventID == "event-42")
        #expect(screen.meetingURL == URL(string: "https://meet.example.com/screen"))
        #expect(screen.prepContext == "Recruiter email: expect systems questions.")
        #expect(screen.outcome == .passed)
        #expect(screen.heardBackAt == Date(timeIntervalSince1970: 1_771_500_000))

        // The attached notes ride through untouched.
        let technical = try #require(stages.last)
        let transcript = try #require(technical.transcript, "the attached notes survive")
        #expect(transcript.recordedAt == Date(timeIntervalSince1970: 1_772_000_000))
        #expect(
            transcript.notesSummary
                == "## Payments outage\n- Walked through the incident timeline\n- Interviewer asked about on-call rotation"
        )
        #expect(transcript.segments.isEmpty)

        // The new link lands nil on migrated rows.
        #expect(screen.debrief == nil)
        #expect(technical.debrief == nil)
        #expect(try context.fetch(FetchDescriptor<Debrief>()).isEmpty)

        // The rest of the Phase 3 store survives alongside.
        let profile = try #require(try context.fetch(FetchDescriptor<Profile>()).first)
        #expect(profile.name == "Matt Alton")
        #expect(profile.roles.count == 1)
        #expect(try context.fetch(FetchDescriptor<DismissedEvent>()).count == 1)
    }
}

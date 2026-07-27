import Foundation
import SwiftData
import Testing

@testable import Ladder

@MainActor
struct JourneyMigrationTests {
    @Test("[JOURNEY-4] a prep-era Application survives the schema migration with its Stages, debriefs and prep packs intact")
    func prepEraStoreSurvivesMigration() throws {
        // The committed fixture store was written by the prep-era Phase 4
        // schema — never regenerate it. Copy it (sidecars too) before
        // opening: migration rewrites the file.
        let fixtureDirectory = try #require(
            Bundle.main.url(forResource: "Phase4PrepStore", withExtension: nil, subdirectory: "Fixtures"),
            "Phase4PrepStore is missing from the bundled Fixtures folder"
        )
        let workDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("phase4prep-migration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workDirectory) }
        for suffix in ["", "-wal", "-shm"] {
            let name = "phase4prep.store\(suffix)"
            let source = fixtureDirectory.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: source.path) else { continue }
            try FileManager.default.copyItem(
                at: source, to: workDirectory.appendingPathComponent(name))
        }
        let url = workDirectory.appendingPathComponent("phase4prep.store")

        let migrated = try ProfileStore.container(at: url)
        let context = ModelContext(migrated)

        let applications = try context.fetch(FetchDescriptor<Application>())
        #expect(applications.count == 1, "every prep-era Application survives")
        let application = try #require(applications.first)
        #expect(application.company == "Summit Labs")
        #expect(application.status == .active)
        #expect(application.appliedAt == Date(timeIntervalSince1970: 1_770_100_000))
        #expect(application.source == "Referral — Jamie")
        #expect(application.notes == "Second round rescheduled twice.")
        #expect(
            application.cvSnapshot == Data("phase-4 snapshot: exact bytes are the point".utf8),
            "snapshot bytes are byte-identical through the migration"
        )

        #expect(application.stages.count == 2, "every Stage survives")
        let stages = application.orderedStages
        #expect(stages.map(\.kind) == [.screen, .technical])
        let screen = try #require(stages.first)
        #expect(screen.outcome == .passed)
        #expect(screen.heardBackAt == Date(timeIntervalSince1970: 1_771_500_000))

        // The attached notes ride through untouched.
        let transcript = try #require(screen.transcript, "the attached notes survive")
        #expect(
            transcript.notesSummary
                == "## Payments outage\n- Walked through the incident timeline\n- Interviewer asked about on-call rotation"
        )

        // The debrief rides through with its links intact.
        let debrief = try #require(screen.debrief, "the debrief survives")
        #expect(debrief.generatedAt == Date(timeIntervalSince1970: 1_772_100_000))
        let question = try #require(debrief.orderedQuestions.first)
        #expect(question.question == "How did you handle the payments outage?")
        #expect(
            question.missedAmmo.map(\.text) == [
                "Led incident response for the payments outage"
            ], "the missed-ammo relationship survives the migration")

        // The prep pack rides through with its talking points and mapped
        // achievements.
        let technical = try #require(stages.last)
        let pack = try #require(technical.prepPack, "the prep pack survives")
        #expect(pack.generatedAt == Date(timeIntervalSince1970: 1_772_300_000))
        #expect(pack.likelyQuestions == ["Walk me through a production incident you owned end to end."])
        #expect(
            pack.orderedTalkingPoints.first?.achievements.map(\.text) == [
                "Led incident response for the payments outage"
            ], "the talking-point relationship survives the migration")

        // The new link lands nil on migrated rows.
        #expect(application.journeyNarrative == nil)
        #expect(try context.fetch(FetchDescriptor<JourneyNarrative>()).isEmpty)

        // The rest of the prep-era store survives alongside.
        let profile = try #require(try context.fetch(FetchDescriptor<Profile>()).first)
        #expect(profile.name == "Matt Alton")
        #expect(profile.roles.count == 1)
        #expect(try context.fetch(FetchDescriptor<DismissedEvent>()).count == 1)
    }
}

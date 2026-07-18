import Foundation
import SwiftData
import Testing

@testable import Ladder

/// The slice's persistence criteria: on-disk stores closed and reopened at
/// the same URL (the [PROFILE-5]/[CVEXPORT-11] pattern, shared helpers in
/// ProfilePersistenceTests.swift). The tracer drives the real path — fixture
/// tailor run → export → Stage — end to end.
@MainActor
struct StagePersistenceTests {
    @Test("[PIPEBOARD-1] a Stage added to an exported Application survives an app relaunch")
    func stageOnExportedApplicationSurvivesRelaunch() async throws {
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }
        var exportedSnapshot = Data()

        do {
            let profileStore = try ProfileStore(container: ProfileStore.container(at: url))
            try profileStore.load()
            try profileStore.createProfile(name: "Alex Climber", headline: "Staff Engineer")
            let role = try profileStore.addRole(
                company: "Acme", title: "Senior Engineer",
                start: Date(timeIntervalSince1970: 1_600_000_000), end: nil
            )
            try profileStore.addAchievement(to: role, text: "Cut CI build times across every product target")
            try profileStore.addAchievement(to: role, text: "Shipped the offline sync engine")
            try profileStore.addAchievement(to: role, text: "Led incident response for the payments outage")

            let tailorStore = TailorStore(
                profileStore: profileStore,
                keyStore: InMemoryAPIKeyStore(key: "sk-test"),
                makeIntelligence: { _ in FixtureIntelligenceService.tailorFixture() }
            )
            await tailorStore.startRun(
                JobDetails(
                    company: "Summit Labs",
                    roleTitle: "Platform Engineer",
                    jobDescription: "Own platform reliability."
                )
            )
            let review = try #require(tailorStore.review)
            let exportStore = CVExportStore(container: profileStore.container)
            let export = try exportStore.export(
                profile: try #require(profileStore.profile), review: review,
                details: JobDetails(
                    company: "Summit Labs",
                    roleTitle: "Platform Engineer",
                    jobDescription: "Own platform reliability."
                )
            )
            exportedSnapshot = export.pdfData

            let pipelineStore = PipelineStore(container: profileStore.container)
            try pipelineStore.load()
            let application = try #require(pipelineStore.applications.first)
            try pipelineStore.addStage(to: application, kind: .technical)
        }

        let reopened = try ProfileStore.container(at: url)
        let context = ModelContext(reopened)
        let applications = try context.fetch(FetchDescriptor<Application>())
        #expect(applications.count == 1)
        let application = try #require(applications.first)
        #expect(application.stages.count == 1)
        #expect(application.orderedStages.first?.kind == .technical)
        #expect(application.cvSnapshot == exportedSnapshot, "snapshot bytes are byte-equal after reopen")
    }

    @Test("[PIPEBOARD-2] a Phase 1 Application survives the schema migration with its CV snapshot byte-identical")
    func phaseOneStoreSurvivesMigration() throws {
        // The committed fixture store was written by the Phase 1 schema
        // (slice AGENTS.md: never regenerate it). Copy it — sidecars too —
        // before opening: migration rewrites the file.
        let fixtureDirectory = try #require(
            Bundle.main.url(forResource: "Phase1Store", withExtension: nil, subdirectory: "Fixtures"),
            "Phase1Store is missing from the bundled Fixtures folder"
        )
        let workDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("phase1-migration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workDirectory) }
        for suffix in ["", "-wal", "-shm"] {
            let name = "phase1.store\(suffix)"
            let source = fixtureDirectory.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: source.path) else { continue }
            try FileManager.default.copyItem(
                at: source, to: workDirectory.appendingPathComponent(name))
        }
        let url = workDirectory.appendingPathComponent("phase1.store")

        let migrated = try ProfileStore.container(at: url)
        let context = ModelContext(migrated)

        let applications = try context.fetch(FetchDescriptor<Application>())
        #expect(applications.count == 1, "every Phase 1 Application survives")
        let application = try #require(applications.first)
        #expect(application.company == "Summit Labs")
        #expect(application.roleTitle == "Platform Engineer")
        #expect(application.jobDescription == "Own platform reliability.")
        #expect(application.status == .applied)
        #expect(
            application.cvSnapshot == Data("phase-1 snapshot: exact bytes are the point".utf8),
            "snapshot bytes are byte-identical through the migration"
        )
        #expect(application.cvSelectionRationale == "CI work maps directly to the JD's platform focus.")
        #expect(application.createdAt == Date(timeIntervalSince1970: 1_770_000_000))
        // New fields land at their defaults — notes' declaration default is
        // exactly what lightweight migration fills existing rows with.
        #expect(application.notes == "")
        #expect(application.source == nil)
        #expect(application.appliedAt == nil, "backfill is load()'s job ([PIPEBOARD-8]), not the migration's")
        #expect(application.stages.isEmpty)

        // The rest of the Phase 1 store survives alongside.
        let profiles = try context.fetch(FetchDescriptor<Profile>())
        let profile = try #require(profiles.first)
        #expect(profile.name == "Matt Alton")
        #expect(profile.roles.count == 1)
        #expect(profile.skills.count == 1)
        #expect(try context.fetch(FetchDescriptor<Achievement>()).count == 1)
    }

    @Test("[PIPEBOARD-3] a fully-populated Stage round-trips through a store reopen")
    func fullyPopulatedStageRoundTrips() throws {
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }
        let scheduledAt = Date(timeIntervalSince1970: 1_771_000_000)
        let heardBackAt = Date(timeIntervalSince1970: 1_771_500_000)
        let meetingURL = try #require(URL(string: "https://meet.example.com/founder-chat"))

        do {
            let container = try ProfileStore.container(at: url)
            let context = ModelContext(container)
            let application = Application(
                company: "Summit Labs", roleTitle: "Platform Engineer",
                jobDescription: "Own platform reliability.", status: .active
            )
            context.insert(application)
            let stage = Stage(
                kind: .other("Founder chat"),
                scheduledAt: scheduledAt,
                calendarEventID: "event-42",
                meetingURL: meetingURL,
                prepContext: "Recruiter email: expect systems questions.",
                outcome: .passed,
                heardBackAt: heardBackAt,
                sortIndex: 3
            )
            context.insert(stage)
            stage.application = application
            try context.save()
        }

        let reopened = try ProfileStore.container(at: url)
        let context = ModelContext(reopened)
        let stages = try context.fetch(FetchDescriptor<Stage>())
        #expect(stages.count == 1)
        let stage = try #require(stages.first)
        #expect(stage.kind == .other("Founder chat"), "an unknown raw value round-trips as .other (decisions/0002)")
        #expect(stage.kindRaw == "Founder chat")
        #expect(stage.scheduledAt == scheduledAt)
        #expect(stage.calendarEventID == "event-42")
        #expect(stage.meetingURL == meetingURL)
        #expect(stage.prepContext == "Recruiter email: expect systems questions.")
        #expect(stage.outcome == .passed)
        #expect(stage.heardBackAt == heardBackAt)
        #expect(stage.sortIndex == 3)
        #expect(stage.application?.company == "Summit Labs")
    }

    @Test("[PIPEBOARD-8] loading backfills the applied date on applied Applications that lack one")
    func loadBackfillsAppliedDate() throws {
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }
        let createdAt = Date(timeIntervalSince1970: 1_770_000_000)
        let ownAppliedAt = Date(timeIntervalSince1970: 1_770_900_000)

        do {
            let container = try ProfileStore.container(at: url)
            let context = ModelContext(container)
            // The Phase 1 shape: applied, no applied date.
            context.insert(
                Application(
                    company: "Needs Backfill", roleTitle: "Engineer", jobDescription: "JD",
                    status: .applied, createdAt: createdAt))
            // Already has one — never touched.
            context.insert(
                Application(
                    company: "Keeps Own Date", roleTitle: "Engineer", jobDescription: "JD",
                    status: .applied, appliedAt: ownAppliedAt, createdAt: createdAt))
            // Not applied — not the backfill's business.
            context.insert(
                Application(
                    company: "Still Draft", roleTitle: "Engineer", jobDescription: "JD",
                    status: .draft, createdAt: createdAt))
            try context.save()

            let store = PipelineStore(container: container)
            try store.load()
            try store.load()  // idempotent: a second load changes nothing
        }

        let reopened = try ProfileStore.container(at: url)
        let context = ModelContext(reopened)
        let byCompany = try Dictionary(
            uniqueKeysWithValues: context.fetch(FetchDescriptor<Application>())
                .map { ($0.company, $0.appliedAt) })
        #expect(byCompany["Needs Backfill"] == createdAt, "the export moment was the creation moment")
        #expect(byCompany["Keeps Own Date"] == ownAppliedAt, "an existing applied date is never touched")
        #expect(byCompany["Still Draft"] == .some(nil), "draft rows are not the backfill's business")
    }

    @Test("[PIPEBOARD-10] Stages keep their added order across a store reopen")
    func stagesKeepAddedOrder() throws {
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }

        do {
            let container = try ProfileStore.container(at: url)
            let context = ModelContext(container)
            let application = Application(
                company: "Summit Labs", roleTitle: "Engineer", jobDescription: "JD",
                status: .active)
            context.insert(application)
            try context.save()

            let store = PipelineStore(container: container)
            try store.load()
            let loaded = try #require(store.applications.first)
            try store.addStage(to: loaded, kind: .screen)
            try store.addStage(to: loaded, kind: .technical)
            try store.addStage(to: loaded, kind: .final)
        }

        let reopened = try ProfileStore.container(at: url)
        let context = ModelContext(reopened)
        let application = try #require(try context.fetch(FetchDescriptor<Application>()).first)
        #expect(
            application.orderedStages.map(\.kind) == [.screen, .technical, .final],
            "sortIndex carries the chain's order — the relationship itself is unordered"
        )
    }

    @Test("[PIPEBOARD-12] source and notes edits on the application detail persist across a store reopen")
    func detailEditsPersist() throws {
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }
        let editedAppliedAt = Date(timeIntervalSince1970: 1_770_800_000)

        do {
            let container = try ProfileStore.container(at: url)
            let context = ModelContext(container)
            context.insert(
                Application(
                    company: "Summit Labs", roleTitle: "Engineer", jobDescription: "JD",
                    status: .active))
            try context.save()

            let store = PipelineStore(container: container)
            try store.load()
            let application = try #require(store.applications.first)
            try store.updateDetails(
                application,
                source: "Referral — Jamie",
                notes: "Second round rescheduled twice.",
                appliedAt: editedAppliedAt
            )
        }

        let reopened = try ProfileStore.container(at: url)
        let context = ModelContext(reopened)
        let application = try #require(try context.fetch(FetchDescriptor<Application>()).first)
        #expect(application.source == "Referral — Jamie")
        #expect(application.notes == "Second round rescheduled twice.")
        #expect(application.appliedAt == editedAppliedAt)
    }

    @Test("[PIPEBOARD-15] Stage edits persist across a store reopen")
    func stageEditsPersist() throws {
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }
        let scheduledAt = Date(timeIntervalSince1970: 1_771_000_000)
        let heardBackAt = Date(timeIntervalSince1970: 1_771_500_000)
        let meetingURL = try #require(URL(string: "https://meet.example.com/loop"))

        do {
            let container = try ProfileStore.container(at: url)
            let context = ModelContext(container)
            let application = Application(
                company: "Summit Labs", roleTitle: "Engineer", jobDescription: "JD",
                status: .active)
            context.insert(application)
            try context.save()

            let store = PipelineStore(container: container)
            try store.load()
            let loaded = try #require(store.applications.first)
            let stage = try store.addStage(to: loaded, kind: .screen)
            try store.updateStage(
                stage,
                kind: .systemDesign,
                scheduledAt: scheduledAt,
                outcome: .passed,
                heardBackAt: heardBackAt,
                prepContext: "Whiteboard the ingest pipeline.",
                meetingURL: meetingURL
            )
        }

        let reopened = try ProfileStore.container(at: url)
        let context = ModelContext(reopened)
        let stage = try #require(try context.fetch(FetchDescriptor<Stage>()).first)
        #expect(stage.kind == .systemDesign)
        #expect(stage.scheduledAt == scheduledAt)
        #expect(stage.outcome == .passed)
        #expect(stage.heardBackAt == heardBackAt)
        #expect(stage.prepContext == "Whiteboard the ingest pipeline.")
        #expect(stage.meetingURL == meetingURL)
    }
}

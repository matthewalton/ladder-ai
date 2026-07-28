import Foundation
import SwiftData
import Testing

@testable import Ladder

@MainActor
struct MatchPersistenceTests {
    @discardableResult
    private func populate(_ container: ModelContainer, scannedAt: Date = .now) throws -> ModelContext {
        let context = ModelContext(container)
        let profile = Profile(name: "Alex Climber", headline: "")
        context.insert(profile)
        let swift = SkillTag(name: "Swift")
        let kubernetes = SkillTag(name: "Kubernetes")
        kubernetes.aliases = ["k8s"]
        profile.skills = [swift, kubernetes]
        let application = Application(
            company: "Acme", roleTitle: "iOS Engineer",
            jobDescription: "Swift and Kubernetes", status: .draft)
        context.insert(application)
        application.match = Match(
            matchedTags: [swift, kubernetes],
            vocabularyGaps: ["GraphQL", "Team leadership"],
            scannedAt: scannedAt)
        try context.save()
        return context
    }

    @Test("[TAILOR-37] a fully-populated Match round-trips through a store reopen")
    func matchRoundTripsThroughReopen() throws {
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }
        let scannedAt = Date(timeIntervalSince1970: 1_753_000_000)

        try populate(try ProfileStore.container(at: url), scannedAt: scannedAt)

        let reopened = try ProfileStore.container(at: url)
        let context = ModelContext(reopened)
        let match = try #require(try context.fetch(FetchDescriptor<Match>()).first)
        #expect(Set(match.matchedTags.map(\.name)) == ["Swift", "Kubernetes"])
        #expect(match.vocabularyGaps == ["GraphQL", "Team leadership"])
        #expect(match.scannedAt == scannedAt)
        #expect(match.application?.company == "Acme")
        let application = try #require(try context.fetch(FetchDescriptor<Application>()).first)
        #expect(application.match === match)
    }

    @Test("[TAILOR-38] deleting an Application removes its Match")
    func deletingApplicationCascadesToMatch() throws {
        let container = try ProfileStore.container(inMemory: true)
        let context = try populate(container)

        let application = try #require(try context.fetch(FetchDescriptor<Application>()).first)
        context.delete(application)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Match>()).isEmpty, "no orphans")
        #expect(
            Set(try context.fetch(FetchDescriptor<SkillTag>()).map(\.name)) == ["Swift", "Kubernetes"],
            "the matched SkillTags themselves survive — only the references go")
    }

    @Test("[TAILOR-39] a pool Tag rename propagates into every Match referencing it")
    func tagRecasePropagatesIntoMatch() throws {
        let container = try ProfileStore.container(inMemory: true)
        try populate(container)

        let profileStore = ProfileStore(container: container)
        try profileStore.load()
        let swift = try #require(profileStore.profile?.skills.first { $0.name == "Swift" })
        try profileStore.recaseTag(swift, to: "SWIFT")

        let fresh = ModelContext(container)
        let match = try #require(try fresh.fetch(FetchDescriptor<Match>()).first)
        #expect(
            Set(match.matchedTags.map(\.name)) == ["SWIFT", "Kubernetes"],
            "matched Tags are the shared instances — the recase shows without touching the Match")
    }

    @Test("[TAILOR-40] deleting a pool Tag removes it from every Match's matched Tags")
    func deletingTagRemovesItFromMatch() throws {
        let container = try ProfileStore.container(inMemory: true)
        let context = try populate(container)

        let kubernetes = try #require(
            try context.fetch(FetchDescriptor<SkillTag>()).first { $0.name == "Kubernetes" })
        context.delete(kubernetes)
        try context.save()

        let fresh = ModelContext(container)
        let match = try #require(try fresh.fetch(FetchDescriptor<Match>()).first)
        #expect(match.matchedTags.map(\.name) == ["Swift"], "the relationship empties, never dangles")
        #expect(
            match.vocabularyGaps == ["GraphQL", "Team leadership"],
            "the ask it covered is not resurrected as a gap — gaps change only when a scan runs")
    }

    @Test("[TAILOR-41] a Match derives its score from its matched and gap counts alone")
    func scoreIsCoveragePercentage() throws {
        #expect(Match.score(matched: 12, gaps: 6) == 67, "12 ÷ 18 = 66.7 → 67")
        #expect(Match.score(matched: 5, gaps: 0) == 100)
        #expect(Match.score(matched: 0, gaps: 5) == 0)
        #expect(Match.score(matched: 5, gaps: 3) == 63, "62.5 rounds half-up")
        #expect(Match.score(matched: 1, gaps: 2) == 33)
        #expect(Match.score(matched: 0, gaps: 0) == nil, "no asks, no score — never a fake 100")

        let container = try ProfileStore.container(inMemory: true)
        let context = try populate(container)
        let match = try #require(try context.fetch(FetchDescriptor<Match>()).first)
        #expect(match.score == 50, "2 matched, 2 gaps — derived on read from the Match itself")
    }

    @Test("[TAILOR-42] a pre-Match store opens with every Application's Match absent")
    func preMatchStoresOpenWithoutMatches() throws {
        // Both committed fixture stores — never regenerate either — travel
        // the full migration chain to the live schema.
        for (directory, file) in [("Phase1Store", "phase1.store"), ("PreTechMigrationStore", "pretech.store")] {
            let fixtureDirectory = try #require(
                Bundle.main.url(forResource: directory, withExtension: nil, subdirectory: "Fixtures"),
                "\(directory) is missing from the bundled Fixtures folder")
            let work = FileManager.default.temporaryDirectory
                .appendingPathComponent("pre-match-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: work) }
            for suffix in ["", "-wal", "-shm"] {
                let source = fixtureDirectory.appendingPathComponent(file + suffix)
                guard FileManager.default.fileExists(atPath: source.path) else { continue }
                try FileManager.default.copyItem(
                    at: source, to: work.appendingPathComponent(file + suffix))
            }

            let container = try ProfileStore.container(at: work.appendingPathComponent(file))
            let context = ModelContext(container)
            #expect(
                try context.fetch(FetchDescriptor<Match>()).isEmpty,
                "\(directory): no Match appears from thin air")
            for application in try context.fetch(FetchDescriptor<Application>()) {
                #expect(application.match == nil, "\(directory): every Application carries no Match")
            }
        }
    }
}

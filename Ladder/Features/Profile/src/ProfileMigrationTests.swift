import Foundation
import SwiftData
import Testing

@testable import Ladder

/// The committed fixture store was written by the pre-migration
/// (tech-carrying) schema — never regenerate it. Copy it (sidecars too)
/// before opening: migration rewrites the file.
@MainActor
struct ProfileMigrationTests {
    private func copyFixtureToTemp() throws -> (work: URL, store: URL) {
        let fixtureDirectory = try #require(
            Bundle.main.url(
                forResource: "PreTechMigrationStore", withExtension: nil, subdirectory: "Fixtures"),
            "PreTechMigrationStore is missing from the bundled Fixtures folder")
        let work = FileManager.default.temporaryDirectory
            .appendingPathComponent("pre-tech-migration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        for suffix in ["", "-wal", "-shm"] {
            let name = "pretech.store\(suffix)"
            let source = fixtureDirectory.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: source.path) else { continue }
            try FileManager.default.copyItem(at: source, to: work.appendingPathComponent(name))
        }
        return (work, work.appendingPathComponent("pretech.store"))
    }

    @Test("[PROFILE-24] opening a pre-migration store folds each achievement's tech strings into its Tags")
    func techFoldsIntoTags() throws {
        let (work, url) = try copyFixtureToTemp()
        defer { try? FileManager.default.removeItem(at: work) }

        let container = try ProfileStore.container(at: url)
        let context = ModelContext(container)
        let profile = try #require(try context.fetch(FetchDescriptor<Profile>()).first)

        #expect(
            Set(profile.skills.map(\.name)) == ["Swift", "Terraform", "Kubernetes", "SwiftUI"],
            "the pool holds the pre-existing Tags plus the folded tech strings")

        let role = try #require(profile.roles.first)
        let points = role.achievements.sorted { $0.sortIndex < $1.sortIndex }
        #expect(points.count == 2)
        let first = try #require(points.first)
        #expect(
            Set(first.skills.map(\.name)) == ["Swift", "Terraform"],
            "the folded \"swift\" resolves onto the existing Swift Tag — no duplicate; Terraform keeps its first-entered casing")
        let second = try #require(points.last)
        #expect(
            Set(second.skills.map(\.name)) == ["Terraform", "Kubernetes"],
            "\"terraform\" resolves onto the Tag the first achievement's fold minted")

        let terraforms = profile.skills.filter {
            $0.name.caseInsensitiveCompare("Terraform") == .orderedSame
        }
        #expect(terraforms.count == 1, "one shared Terraform Tag, linked from both points")
        #expect(terraforms.first?.name == "Terraform", "first casing wins over the later \"terraform\"")

        let project = try #require(profile.projects.first)
        #expect(project.skills.map(\.name) == ["SwiftUI"], "project Tags ride through untouched")
    }

    @Test("[PROFILE-25] the tech migration writes a store-file backup before it runs")
    func backupWrittenBeforeMigration() throws {
        let (work, url) = try copyFixtureToTemp()
        defer { try? FileManager.default.removeItem(at: work) }
        let fixtureDirectory = try #require(
            Bundle.main.url(
                forResource: "PreTechMigrationStore", withExtension: nil, subdirectory: "Fixtures"))
        let originalBytes = try Data(
            contentsOf: fixtureDirectory.appendingPathComponent("pretech.store"))

        _ = try ProfileStore.container(at: url)

        let backup = URL(fileURLWithPath: url.path + ".pre-migration-backup")
        #expect(FileManager.default.fileExists(atPath: backup.path))
        #expect(
            try Data(contentsOf: backup) == originalBytes,
            "the backup is the pre-migration bytes — copied before anything touched the store")
    }

    @Test("[PROFILE-25] an already-migrated store writes no backup")
    func noBackupOnMigratedStore() throws {
        let (work, url) = try copyFixtureToTemp()
        defer { try? FileManager.default.removeItem(at: work) }
        do { _ = try ProfileStore.container(at: url) }

        let backup = URL(fileURLWithPath: url.path + ".pre-migration-backup")
        try? FileManager.default.removeItem(at: backup)
        _ = try ProfileStore.container(at: url)
        #expect(
            !FileManager.default.fileExists(atPath: backup.path),
            "the net exists for the one-way step, not every launch")
    }

    @Test("[PROFILE-24] a migrated store reopens without re-folding")
    func migratedStoreReopensCleanly() throws {
        let (work, url) = try copyFixtureToTemp()
        defer { try? FileManager.default.removeItem(at: work) }
        do {
            let container = try ProfileStore.container(at: url)
            _ = try ModelContext(container).fetch(FetchDescriptor<Profile>())
        }
        let container = try ProfileStore.container(at: url)
        let context = ModelContext(container)
        let profile = try #require(try context.fetch(FetchDescriptor<Profile>()).first)
        #expect(profile.skills.count == 4, "no duplicate Tags on reopen")
        let role = try #require(profile.roles.first)
        let first = try #require(role.achievements.min(by: { $0.sortIndex < $1.sortIndex }))
        #expect(first.skills.count == 2, "links did not double")
    }
}

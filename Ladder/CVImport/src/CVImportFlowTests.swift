import Foundation
import SwiftData
import Testing

@testable import Ladder

/// The import flow's criteria, against an in-memory Profile store and the
/// fixture intelligence service. Fixture CVs and the canned proposal load
/// from the app bundle's Fixtures folder (tests run in the app host).
@MainActor
struct CVImportFlowTests {
    private func makeProfileStore(createProfile: Bool = true) throws -> ProfileStore {
        let store = try ProfileStore(container: ProfileStore.container(inMemory: true))
        try store.load()
        if createProfile {
            try store.createProfile(name: "Alex Climber", headline: "Staff Engineer")
        }
        return store
    }

    private func fixtureURL(_ name: String, _ ext: String) throws -> URL {
        try #require(
            Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Fixtures"),
            "\(name).\(ext) missing from the bundled Fixtures folder"
        )
    }

    @Test("[CVIMPORT-1] importing a PDF CV produces a proposal of roles for review")
    func pdfImportProducesProposalForReview() async throws {
        let profileStore = try makeProfileStore()
        let store = ImportStore(
            profileStore: profileStore,
            intelligence: FixtureIntelligenceService.importFixture()
        )

        await store.startImport(of: try fixtureURL("sample-cv", "pdf"))

        #expect(store.phase == .review)
        let review = try #require(store.review)
        #expect(review.roles.map(\.proposed.company) == ["Acme", "Initech"])
        #expect(review.roles.first?.achievements.map(\.proposed.text) == [
            "Cut CI build times across every product target",
            "Shipped the offline sync engine",
        ])
        // The proposal is transient — nothing lands before the merge.
        #expect(profileStore.profile?.roles.isEmpty == true)
    }

    @Test("[CVIMPORT-2] importing a docx CV produces a proposal of roles for review")
    func docxImportProducesProposalForReview() async throws {
        let profileStore = try makeProfileStore()
        let store = ImportStore(
            profileStore: profileStore,
            intelligence: FixtureIntelligenceService.importFixture()
        )

        await store.startImport(of: try fixtureURL("sample-cv", "docx"))

        #expect(store.phase == .review)
        let review = try #require(store.review)
        #expect(review.roles.map(\.proposed.company) == ["Acme", "Initech"])
    }

    @Test("[CVIMPORT-3] starting an import when no Profile exists is refused")
    func importWithoutProfileIsRefused() async throws {
        let profileStore = try makeProfileStore(createProfile: false)
        let service = FixtureIntelligenceService.importFixture()
        let store = ImportStore(profileStore: profileStore, intelligence: service)

        await store.startImport(of: try fixtureURL("sample-cv", "pdf"))

        #expect(store.phase == .failed(.profileRequired))
        #expect(store.review == nil)
        // Refused at start, before any extraction or service call
        // (SPEC.md [CVIMPORT-3] body).
        #expect(await service.recordedRequests.isEmpty)
    }

    @Test("[CVIMPORT-4] every proposed item enters review as included")
    func reviewDefaultsEverythingToIncluded() async throws {
        let store = ImportStore(
            profileStore: try makeProfileStore(),
            intelligence: FixtureIntelligenceService.importFixture()
        )

        await store.startImport(of: try fixtureURL("sample-cv", "pdf"))

        let review = try #require(store.review)
        for role in review.roles {
            #expect(role.included)
            for achievement in role.achievements {
                #expect(achievement.included)
                for skill in achievement.skills {
                    #expect(skill.included)
                }
            }
        }
    }

    @Test("[CVIMPORT-5] confirming the review adds each included proposed role with its achievements to the Profile")
    func confirmMergesIncludedRolesAndAchievements() async throws {
        let profileStore = try makeProfileStore()
        let store = ImportStore(
            profileStore: profileStore,
            intelligence: FixtureIntelligenceService.importFixture()
        )
        await store.startImport(of: try fixtureURL("sample-cv", "pdf"))

        store.confirmReview()

        #expect(store.phase == .merged)
        #expect(store.review == nil)
        let profile = try #require(profileStore.profile)
        #expect(profile.roles.count == 2)

        let acme = try #require(profile.roles.first { $0.company == "Acme" })
        #expect(acme.title == "Senior Engineer")
        #expect(acme.start == monthDate(2021, 4))
        #expect(acme.end == nil, "a null proposal end is a current role")
        #expect(acme.orderedAchievements.map(\.text) == [
            "Cut CI build times across every product target",
            "Shipped the offline sync engine",
        ])
        let first = try #require(acme.orderedAchievements.first)
        #expect(first.impactMetric == "reduced build time 40%")
        #expect(first.tech == ["Swift", "Bazel"])
        #expect(Set(first.skills.map(\.name)) == ["Swift", "CI"])

        let initech = try #require(profile.roles.first { $0.company == "Initech" })
        #expect(initech.start == monthDate(2018, 9))
        #expect(initech.end == monthDate(2021, 3))
    }

    @Test("[CVIMPORT-6] a proposed item excluded in review does not land in the Profile")
    func excludedItemsDoNotLand() async throws {
        let profileStore = try makeProfileStore()
        let store = ImportStore(
            profileStore: profileStore,
            intelligence: FixtureIntelligenceService.importFixture()
        )
        await store.startImport(of: try fixtureURL("sample-cv", "pdf"))
        let review = try #require(store.review)

        // Excluding a role excludes its achievements with it; excluding one
        // achievement keeps the role's others; excluding a skill keeps the
        // achievement (SPEC.md [CVIMPORT-6] body).
        try #require(review.roles.count == 2)
        review.roles[1].included = false
        review.roles[0].achievements[1].included = false
        let firstAchievement = review.roles[0].achievements[0]
        try #require(firstAchievement.skills.map(\.name) == ["Swift", "CI"])
        firstAchievement.skills[1].included = false

        store.confirmReview()

        let profile = try #require(profileStore.profile)
        #expect(profile.roles.map(\.company) == ["Acme"])
        let acme = try #require(profile.roles.first)
        #expect(acme.orderedAchievements.map(\.text) == [
            "Cut CI build times across every product target"
        ])
        #expect(acme.orderedAchievements.first?.skills.map(\.name) == ["Swift"])
    }

    @Test("[CVIMPORT-7] merged roles and achievements are still present after the app relaunches")
    func mergedContentSurvivesRelaunch() async throws {
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }

        do {
            let profileStore = try ProfileStore(container: ProfileStore.container(at: url))
            try profileStore.load()
            try profileStore.createProfile(name: "Alex Climber", headline: "Staff Engineer")
            let store = ImportStore(
                profileStore: profileStore,
                intelligence: FixtureIntelligenceService.importFixture()
            )
            await store.startImport(of: try fixtureURL("sample-cv", "pdf"))
            store.confirmReview()
            #expect(store.phase == .merged)
        }

        let reopened = try ProfileStore(container: ProfileStore.container(at: url))
        try reopened.load()
        let profile = try #require(reopened.profile)
        #expect(Set(profile.roles.map(\.company)) == ["Acme", "Initech"])
        let acme = try #require(profile.roles.first { $0.company == "Acme" })
        #expect(acme.orderedAchievements.map(\.text) == [
            "Cut CI build times across every product target",
            "Shipped the offline sync engine",
        ])
    }

    @Test("[CVIMPORT-8] merging a proposed skill whose name matches an existing SkillTag reuses the shared tag")
    func mergedSkillsReuseExistingTags() async throws {
        let profileStore = try makeProfileStore()
        let existingRole = try profileStore.addRole(
            company: "Existing Co", title: "Engineer", start: .now, end: nil
        )
        let existingAchievement = try profileStore.addAchievement(
            to: existingRole, text: "Kept the lights on"
        )
        let existingTag = try profileStore.tag(existingAchievement, skillNamed: "Swift")

        // The SPEC.md [CVIMPORT-8] body's worked case: the proposal names
        // " swift " where the Profile already has "Swift".
        let proposalJSON = Data("""
        {
          "roles": [
            {
              "company": "Acme",
              "title": "Senior Engineer",
              "start": "2021-04",
              "end": null,
              "achievements": [
                {
                  "text": "Cut CI build times across every product target",
                  "impactMetric": null,
                  "tech": [],
                  "skills": [" swift "]
                }
              ]
            }
          ],
          "notImportedSections": []
        }
        """.utf8)
        let store = ImportStore(
            profileStore: profileStore,
            intelligence: FixtureIntelligenceService(returning: proposalJSON)
        )
        await store.startImport(of: try fixtureURL("sample-cv", "pdf"))

        store.confirmReview()

        let profile = try #require(profileStore.profile)
        #expect(profile.skills.count == 1, "no new SkillTag for a matching name")
        let acme = try #require(profile.roles.first { $0.company == "Acme" })
        let merged = try #require(acme.orderedAchievements.first)
        #expect(merged.skills.first === existingTag)
        #expect(merged.skills.map(\.name) == ["Swift"], "the surviving tag keeps the name as first entered")
    }

    @Test("[CVIMPORT-9] education and project sections of the CV are listed as not-imported in the review")
    func outOfScopeSectionsAreListedNotImported() async throws {
        let profileStore = try makeProfileStore()
        let store = ImportStore(
            profileStore: profileStore,
            intelligence: FixtureIntelligenceService.importFixture()
        )

        await store.startImport(of: try fixtureURL("sample-cv", "pdf"))

        let review = try #require(store.review)
        #expect(review.notImportedSections.map(\.name) == ["Education", "Projects"])
        #expect(review.notImportedSections.first?.content.contains("University of Leeds") == true)

        // Never silently dropped, never merged (decisions/0002).
        store.confirmReview()
        let profile = try #require(profileStore.profile)
        #expect(Set(profile.roles.map(\.company)) == ["Acme", "Initech"])
    }

    @Test("[CVIMPORT-10] a proposal failing schema validation fails the import")
    func invalidProposalFailsTheImport() async throws {
        let profileStore = try makeProfileStore()
        let store = ImportStore(
            profileStore: profileStore,
            intelligence: FixtureIntelligenceService(returning: Data(#"{"roles": "not an array"}"#.utf8))
        )

        await store.startImport(of: try fixtureURL("sample-cv", "pdf"))

        #expect(store.phase == .failed(.proposalInvalid))
        #expect(store.review == nil, "no review is offered")
        #expect(profileStore.profile?.roles.isEmpty == true, "the Profile is unchanged")
    }

    @Test("[CVIMPORT-11] a CV yielding no extractable text fails the import")
    func textlessCVFailsTheImport() async throws {
        let profileStore = try makeProfileStore()
        let service = FixtureIntelligenceService.importFixture()
        let store = ImportStore(profileStore: profileStore, intelligence: service)

        await store.startImport(of: try fixtureURL("image-only", "pdf"))

        #expect(store.phase == .failed(.extractionFailed))
        #expect(await service.recordedRequests.isEmpty, "fails before any service call")
        #expect(profileStore.profile?.roles.isEmpty == true)
    }

    @Test("[CVIMPORT-12] a file that is neither PDF nor docx is rejected")
    func unsupportedFileTypeIsRejected() async throws {
        let profileStore = try makeProfileStore()
        let service = FixtureIntelligenceService.importFixture()
        let store = ImportStore(profileStore: profileStore, intelligence: service)

        let txt = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("cv-\(UUID().uuidString).txt")
        try "A CV in the wrong format".write(to: txt, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: txt) }

        await store.startImport(of: txt)

        #expect(store.phase == .failed(.unsupportedFileType))
        #expect(await service.recordedRequests.isEmpty, "judged before extraction is attempted")
    }

    @Test("[CVIMPORT-13] the proposal request contains the versioned import prompt")
    func proposalRequestCarriesTheBundledPrompt() async throws {
        let profileStore = try makeProfileStore()
        let service = FixtureIntelligenceService.importFixture()
        let store = ImportStore(profileStore: profileStore, intelligence: service)

        await store.startImport(of: try fixtureURL("sample-cv", "pdf"))

        let promptURL = try #require(
            Bundle.main.url(forResource: "import", withExtension: "md", subdirectory: "Prompts"),
            "Prompts/import.md missing from the app bundle"
        )
        let promptOnDisk = try String(contentsOf: promptURL, encoding: .utf8)
        let requests = await service.recordedRequests
        #expect(requests.count == 1)
        #expect(requests.first?.prompt == promptOnDisk, "the prompt is the file's content, never an inline string")
        #expect(requests.first?.payload.contains("Alex Climber") == true, "the payload is the extracted CV text")
    }
}

/// Proposal dates are month-resolution UTC (ImportProposal.parseMonth).
@MainActor
private func monthDate(_ year: Int, _ month: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar.date(from: components)!
}

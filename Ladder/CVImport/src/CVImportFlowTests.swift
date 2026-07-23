import Foundation
import SwiftData
import Testing

@testable import Ladder

/// Fixture CVs and the canned proposal load from the app bundle's Fixtures
/// folder (tests run in the app host).
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

    /// A fake key store holding a key keeps the live-wiring guards out of
    /// the way of criteria that aren't about them.
    private func makeImportStore(
        profileStore: ProfileStore,
        service: FixtureIntelligenceService,
        keyStore: any APIKeyStore = InMemoryAPIKeyStore(key: "test-key")
    ) -> ImportStore {
        ImportStore(
            profileStore: profileStore,
            keyStore: keyStore,
            makeIntelligence: { _ in service }
        )
    }

    @Test("[CVIMPORT-1] importing a PDF CV produces a proposal of roles for review")
    func pdfImportProducesProposalForReview() async throws {
        let profileStore = try makeProfileStore()
        let store = makeImportStore(
            profileStore: profileStore,
            service: FixtureIntelligenceService.importFixture()
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

    @Test("[CVIMPORT-31] the proposal lists each achievement's title and description for review")
    func proposalSplitsAchievementTitleAndDescription() async throws {
        let profileStore = try makeProfileStore()
        let store = makeImportStore(
            profileStore: profileStore,
            service: FixtureIntelligenceService.importFixture()
        )

        await store.startImport(of: try fixtureURL("sample-cv", "pdf"))

        let review = try #require(store.review)
        let achievements = try #require(review.roles.first?.achievements)
        #expect(achievements.map(\.proposed.title) == ["Rebuilt the CI pipeline", nil],
                "a bullet with a bold lead-in splits; one without proposes a null title")
        #expect(achievements.map(\.proposed.text) == [
            "Cut CI build times across every product target",
            "Shipped the offline sync engine",
        ])

        // Confirmed titles land through the replace pathway ([PROFILE-17]).
        store.confirmReview()
        let landed = try #require(profileStore.profile?.roles
            .first { $0.company == "Acme" }?.orderedAchievements)
        #expect(landed.map(\.title) == ["Rebuilt the CI pipeline", nil])
    }

    @Test("[CVIMPORT-2] importing a docx CV produces a proposal of roles for review")
    func docxImportProducesProposalForReview() async throws {
        let profileStore = try makeProfileStore()
        let store = makeImportStore(
            profileStore: profileStore,
            service: FixtureIntelligenceService.importFixture()
        )

        await store.startImport(of: try fixtureURL("sample-cv", "docx"))

        #expect(store.phase == .review)
        let review = try #require(store.review)
        #expect(review.roles.map(\.proposed.company) == ["Acme", "Initech"])
    }

    @Test("[CVIMPORT-21] confirming a review with no Profile on file creates the single Profile")
    func confirmWithNoProfileCreatesIt() async throws {
        let profileStore = try makeProfileStore(createProfile: false)
        let store = makeImportStore(
            profileStore: profileStore,
            service: FixtureIntelligenceService.importFixture()
        )
        #expect(!store.needsReplaceConfirmation, "nothing to lose — no replace confirmation on this branch")

        await store.startImport(of: try fixtureURL("sample-cv", "pdf"))
        #expect(store.phase == .review)
        store.confirmReview()

        #expect(store.phase == .replaced)
        let profile = try #require(profileStore.profile)
        #expect(profile.name == "Alex Climber")
        #expect(profile.headline == "Staff Engineer")
        #expect(profile.roles.count == 2)
        let count = try ModelContext(profileStore.container).fetchCount(FetchDescriptor<Profile>())
        #expect(count == 1, "the single-profile invariant holds through the create branch")
    }

    @Test("[CVIMPORT-22] starting an import onto an existing Profile requires confirmation before the run begins")
    func importOntoExistingProfileNeedsConfirmation() async throws {
        // The needs-confirmation decision is a pure helper — the dialog
        // chrome gates on it; declining never calls startImport.
        let service = FixtureIntelligenceService.importFixture()
        let withProfile = makeImportStore(profileStore: try makeProfileStore(), service: service)
        #expect(withProfile.needsReplaceConfirmation)

        let withoutProfile = makeImportStore(
            profileStore: try makeProfileStore(createProfile: false),
            service: FixtureIntelligenceService.importFixture()
        )
        #expect(!withoutProfile.needsReplaceConfirmation)

        // Declining aborts before extraction and before any service call:
        // the store was never started, so nothing ran and nothing changed.
        #expect(withProfile.phase == .idle)
        #expect(await service.recordedRequests.isEmpty)
    }

    @Test("[CVIMPORT-4] every proposed item enters review as included")
    func reviewDefaultsEverythingToIncluded() async throws {
        let store = makeImportStore(
            profileStore: try makeProfileStore(),
            service: FixtureIntelligenceService.importFixture()
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
        for education in review.education {
            #expect(education.included)
        }
        for project in review.projects {
            #expect(project.included)
            for skill in project.skills {
                #expect(skill.included)
            }
        }
        for interest in review.interests {
            #expect(interest.included)
        }
    }

    @Test("[CVIMPORT-20] confirming the review replaces the Profile's content with the included items")
    func confirmReplacesProfileContent() async throws {
        let profileStore = try makeProfileStore()
        // Curated content that must be gone after the hard refresh.
        let oldRole = try profileStore.addRole(
            company: "OldCo", title: "Old Engineer", start: .now, end: nil
        )
        let oldAchievement = try profileStore.addAchievement(to: oldRole, text: "Old achievement")
        try profileStore.tag(oldAchievement, skillNamed: "OldSkill")
        try profileStore.addEducation(
            institution: "Old University", qualification: "Old BSc", start: .now, end: nil
        )
        try profileStore.addInterest("Old interest")

        let store = makeImportStore(
            profileStore: profileStore,
            service: FixtureIntelligenceService.importFixture()
        )
        await store.startImport(of: try fixtureURL("sample-cv", "pdf"))

        store.confirmReview()

        #expect(store.phase == .replaced)
        #expect(store.review == nil)
        let profile = try #require(profileStore.profile)
        #expect(Set(profile.roles.map(\.company)) == ["Acme", "Initech"], "old roles are gone — never a merged hybrid")
        #expect(profile.education.map(\.institution) == ["University of Leeds"])
        #expect(profile.projects.map(\.name) == ["Trail Mapper"])
        #expect(profile.interests == ["Climbing", "Trail running"])

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

        // The Tag pool is rebuilt from the replacement alone; "Swift" is
        // named by a role achievement and a project yet lands once.
        #expect(Set(profile.skills.map(\.name)) == ["Swift", "CI", "SwiftData", "Python", "MapKit"])
        let swift = try #require(profile.skills.first { $0.name == "Swift" })
        let project = try #require(profile.projects.first)
        #expect(project.details == "An offline-first hiking map app with tile caching and route planning, built to survive a week without signal.")
        #expect(project.skills.contains { $0 === swift }, "the same skill name shares one Tag across the replacement")
    }

    @Test("[CVIMPORT-6] a proposed item excluded in review does not land in the Profile")
    func excludedItemsDoNotLand() async throws {
        let profileStore = try makeProfileStore()
        let store = makeImportStore(
            profileStore: profileStore,
            service: FixtureIntelligenceService.importFixture()
        )
        await store.startImport(of: try fixtureURL("sample-cv", "pdf"))
        let review = try #require(store.review)

        // Excluding a role excludes its achievements with it; excluding one
        // achievement keeps the role's others; excluding a skill keeps the
        // achievement.
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
            let store = makeImportStore(
                profileStore: profileStore,
                service: FixtureIntelligenceService.importFixture()
            )
            await store.startImport(of: try fixtureURL("sample-cv", "pdf"))
            store.confirmReview()
            #expect(store.phase == .replaced)
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

    @Test("[CVIMPORT-23] the proposal carries the CV's identity and contact details")
    func proposalCarriesIdentityAndContact() async throws {
        let profileStore = try makeProfileStore(createProfile: false)
        let store = makeImportStore(
            profileStore: profileStore,
            service: FixtureIntelligenceService.importFixture()
        )

        await store.startImport(of: try fixtureURL("sample-cv", "pdf"))

        let review = try #require(store.review)
        #expect(review.identity.name == "Alex Climber")
        #expect(review.identity.headline == "Staff Engineer")
        #expect(review.identity.contact.email == "alex@example.com")
        #expect(review.identity.contact.phone == "+44 7700 900123")
        #expect(review.identity.contact.location == "Leeds, UK")
        #expect(review.identity.contact.link == "https://alex.dev")

        store.confirmReview()
        let profile = try #require(profileStore.profile)
        #expect(profile.contact == ContactInfo(
            email: "alex@example.com", phone: "+44 7700 900123",
            location: "Leeds, UK", link: "https://alex.dev"
        ))

        // A proposal whose identity has no name fails validation with its
        // reason — a fresh Profile needs a name.
        let nameless = Data("""
        {
          "identity": {
            "name": "  ",
            "headline": null,
            "contact": { "email": null, "phone": null, "location": null, "link": null }
          },
          "roles": [], "education": [], "projects": [], "interests": [],
          "notImportedSections": []
        }
        """.utf8)
        let namelessStore = makeImportStore(
            profileStore: profileStore,
            service: FixtureIntelligenceService(returning: nameless)
        )
        await namelessStore.startImport(of: try fixtureURL("sample-cv", "pdf"))
        guard case .failed(.proposalInvalid(let reason)) = namelessStore.phase else {
            Issue.record("expected .failed(.proposalInvalid), got \(namelessStore.phase)")
            return
        }
        #expect(reason.contains("identity.name"), "the reason names the empty identity, got: \(reason)")
    }

    @Test("[CVIMPORT-24] the proposal lists the CV's education entries for review")
    func proposalListsEducationForReview() async throws {
        let profileStore = try makeProfileStore()
        let store = makeImportStore(
            profileStore: profileStore,
            service: FixtureIntelligenceService.importFixture()
        )
        await store.startImport(of: try fixtureURL("sample-cv", "pdf"))

        let review = try #require(store.review)
        let education = try #require(review.education.first)
        #expect(review.education.count == 1)
        #expect(education.proposed.institution == "University of Leeds")
        #expect(education.proposed.qualification == "BSc Computer Science")
        #expect(education.proposed.start == monthDate(2014, 9))
        #expect(education.proposed.end == monthDate(2017, 6))
        #expect(education.proposed.detail == "First-class honours")

        // An excluded education entry is simply absent from the replacement.
        education.included = false
        store.confirmReview()
        #expect(profileStore.profile?.education.isEmpty == true)
    }

    @Test("[CVIMPORT-28] the proposal lists the CV's projects with description and skills for review")
    func proposalListsProjectsWithDescriptionAndSkillsForReview() async throws {
        let profileStore = try makeProfileStore()
        let store = makeImportStore(
            profileStore: profileStore,
            service: FixtureIntelligenceService.importFixture()
        )
        await store.startImport(of: try fixtureURL("sample-cv", "pdf"))

        let review = try #require(store.review)
        let project = try #require(review.projects.first)
        #expect(project.proposed.name == "Trail Mapper")
        #expect(project.proposed.link == "https://github.com/alex/trail-mapper")
        #expect(project.proposed.summary == "Offline-first hiking maps")
        #expect(project.proposed.description == "An offline-first hiking map app with tile caching and route planning, built to survive a week without signal.")
        #expect(project.skills.map(\.name) == ["Swift", "MapKit"])

        // Excluding one proposed skill keeps the project confirmable.
        project.skills[1].included = false
        store.confirmReview()
        let landed = try #require(profileStore.profile?.projects.first)
        #expect(landed.skills.map(\.name) == ["Swift"])
    }

    @Test("[CVIMPORT-28] an excluded project is absent from the replacement wholesale")
    func excludedProjectDoesNotLand() async throws {
        let profileStore = try makeProfileStore()
        let store = makeImportStore(
            profileStore: profileStore,
            service: FixtureIntelligenceService.importFixture()
        )
        await store.startImport(of: try fixtureURL("sample-cv", "pdf"))

        let review = try #require(store.review)
        let project = try #require(review.projects.first)
        project.included = false
        store.confirmReview()
        let profile = try #require(profileStore.profile)
        #expect(profile.projects.isEmpty)
        #expect(Set(profile.roles.map(\.company)) == ["Acme", "Initech"], "the rest of the review still lands")
    }

    @Test("[CVIMPORT-29] a contact value detected in the CV overrides the service's proposal for that field")
    func detectedContactOverridesProposal() throws {
        // The worked example from the criterion: the real CV header whose
        // contact the live model returned as null.
        let text = """
        MATTHEW ALTON
        Software Engineer · Agentic Workflows · React / TypeScript
        London, UK · 07541 964763 · mattalton97@gmail.com
        PROFILE
        Software engineer with 5 years building React/TypeScript apps.
        Baton — Native macOS kanban board github.com/matthewalton/baton
        """

        let detected = DetectedContact.detect(in: text)

        #expect(detected.email == "mattalton97@gmail.com")
        #expect(detected.phone == "07541 964763")
        #expect(detected.link == nil, "a URL outside the header region is a project link, not the personal one")

        let overridden = detected.overriding(ProposedContact(
            email: nil, phone: "999", location: "Leeds", link: nil
        ))
        #expect(overridden.email == "mattalton97@gmail.com", "detection fills what the model omitted")
        #expect(overridden.phone == "07541 964763", "a detected value wins over the model's")
        #expect(overridden.location == "Leeds", "location stays with the model")
        #expect(overridden.link == nil)
    }

    @Test("[CVIMPORT-29] first match per field wins")
    func firstDetectedMatchWinsPerField() throws {
        let text = """
        Alex Climber
        alex@example.com · github.com/alexclimber
        Experience
        References available from referee@oldco.com
        """

        let detected = DetectedContact.detect(in: text)

        #expect(detected.email == "alex@example.com", "a referee's email never displaces the owner's")
        #expect(detected.link?.contains("github.com/alexclimber") == true, "a header URL is the personal link")
    }

    @Test("[CVIMPORT-29] a detected value reaches the review over a null-contact proposal")
    func detectionFlowsIntoTheReview() async throws {
        let profileStore = try makeProfileStore()
        // The model returns identity with null contact; the fixture PDF's
        // header text carries alex@example.com.
        let nullContact = Data("""
        {
          "identity": {
            "name": "Alex Climber",
            "headline": "Staff Engineer",
            "contact": { "email": null, "phone": null, "location": null, "link": null }
          },
          "roles": [], "education": [], "projects": [], "interests": [],
          "notImportedSections": []
        }
        """.utf8)
        let store = makeImportStore(
            profileStore: profileStore,
            service: FixtureIntelligenceService(returning: nullContact)
        )

        await store.startImport(of: try fixtureURL("sample-cv", "pdf"))

        let review = try #require(store.review)
        #expect(review.identity.contact.email == "alex@example.com",
                "detection runs between extraction and review")
    }

    @Test("[CVIMPORT-30] a contact field with no detected value keeps the service's proposed value")
    func undetectedFieldsKeepTheProposal() throws {
        let text = """
        Alex Climber
        Staff Engineer
        Leeds
        Experience
        Acme — Senior Engineer
        """

        let detected = DetectedContact.detect(in: text)
        #expect(detected.email == nil)
        #expect(detected.link == nil)

        let contact = ProposedContact(
            email: "alex@example.com", phone: nil, location: "Leeds, UK", link: "https://alex.dev"
        )
        let overridden = detected.overriding(contact)
        #expect(overridden == contact, "detection fills, never blanks")
    }

    @Test("[CVIMPORT-26] the proposal lists the CV's interests for review")
    func proposalListsInterestsForReview() async throws {
        let profileStore = try makeProfileStore()
        let store = makeImportStore(
            profileStore: profileStore,
            service: FixtureIntelligenceService.importFixture()
        )
        await store.startImport(of: try fixtureURL("sample-cv", "pdf"))

        let review = try #require(store.review)
        #expect(review.interests.map(\.name) == ["Climbing", "Trail running"], "the CV's own order")

        // An excluded interest is simply absent from the replacement.
        try #require(review.interests.count == 2)
        review.interests[1].included = false
        store.confirmReview()
        #expect(profileStore.profile?.interests == ["Climbing"])
    }

    @Test("[CVIMPORT-27] a CV section outside the import scope is listed as not-imported in the review")
    func outOfScopeSectionsAreListedNotImported() async throws {
        let profileStore = try makeProfileStore()
        let store = makeImportStore(
            profileStore: profileStore,
            service: FixtureIntelligenceService.importFixture()
        )

        await store.startImport(of: try fixtureURL("sample-cv", "pdf"))

        let review = try #require(store.review)
        #expect(review.notImportedSections.map(\.name) == ["Profile"])
        #expect(review.notImportedSections.first?.content.contains("decade of platform") == true)

        // Not-imported sections are never written anywhere: the fresh
        // Profile holds exactly the schema'd sections.
        store.confirmReview()
        let profile = try #require(profileStore.profile)
        #expect(Set(profile.roles.map(\.company)) == ["Acme", "Initech"])
        #expect(profile.headline == "Staff Engineer", "the summary paragraph lands nowhere — headline is the CV's own title line")
    }

    @Test("[CVIMPORT-10] a proposal failing schema validation fails the import")
    func invalidProposalFailsTheImport() async throws {
        let profileStore = try makeProfileStore()
        let store = makeImportStore(
            profileStore: profileStore,
            service: FixtureIntelligenceService(returning: Data(#"{"roles": "not an array"}"#.utf8))
        )

        await store.startImport(of: try fixtureURL("sample-cv", "pdf"))

        if case .failed(.proposalInvalid) = store.phase {} else {
            Issue.record("expected .failed(.proposalInvalid), got \(store.phase)")
        }
        #expect(store.review == nil, "no review is offered")
        #expect(profileStore.profile?.roles.isEmpty == true, "the Profile is unchanged")
    }

    @Test("[CVIMPORT-11] a CV yielding no extractable text fails the import")
    func textlessCVFailsTheImport() async throws {
        let profileStore = try makeProfileStore()
        let service = FixtureIntelligenceService.importFixture()
        let store = makeImportStore(profileStore: profileStore, service: service)

        await store.startImport(of: try fixtureURL("image-only", "pdf"))

        #expect(store.phase == .failed(.extractionFailed))
        #expect(await service.recordedRequests.isEmpty, "fails before any service call")
        #expect(profileStore.profile?.roles.isEmpty == true)
    }

    @Test("[CVIMPORT-12] a file that is neither PDF nor docx is rejected")
    func unsupportedFileTypeIsRejected() async throws {
        let profileStore = try makeProfileStore()
        let service = FixtureIntelligenceService.importFixture()
        let store = makeImportStore(profileStore: profileStore, service: service)

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
        let store = makeImportStore(profileStore: profileStore, service: service)

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

    @Test("[CVIMPORT-14] starting an import with no API key stored is refused")
    func importWithNoStoredKeyIsRefused() async throws {
        let profileStore = try makeProfileStore()
        let service = FixtureIntelligenceService.importFixture()
        let store = makeImportStore(
            profileStore: profileStore,
            service: service,
            keyStore: InMemoryAPIKeyStore()
        )

        await store.startImport(of: try fixtureURL("sample-cv", "pdf"))

        #expect(store.phase == .failed(.apiKeyRequired))
        #expect(store.review == nil)
        // Refused before any extraction or service call.
        #expect(await service.recordedRequests.isEmpty)
    }

    @Test("[CVIMPORT-15] the import run creates its live service with the stored API key")
    func importRunCreatesItsServiceWithTheStoredKey() async throws {
        let profileStore = try makeProfileStore()
        let service = FixtureIntelligenceService.importFixture()
        let receivedKey = KeyBox()
        let store = ImportStore(
            profileStore: profileStore,
            keyStore: InMemoryAPIKeyStore(key: "sk-ladder-import-test"),
            makeIntelligence: { key in
                receivedKey.value = key
                return service
            }
        )

        await store.startImport(of: try fixtureURL("sample-cv", "pdf"))

        #expect(receivedKey.value == "sk-ladder-import-test", "the factory receives exactly the stored key")
        #expect(store.phase == .review)
    }

    @Test("[CVIMPORT-16] a failed live request ends the import in the request-failed state")
    func failedLiveRequestEndsInRequestFailed() async throws {
        let profileStore = try makeProfileStore()
        let store = ImportStore(
            profileStore: profileStore,
            keyStore: InMemoryAPIKeyStore(key: "test-key"),
            makeIntelligence: { _ in ThrowingIntelligenceService(error: .httpFailure(status: 429)) }
        )

        await store.startImport(of: try fixtureURL("sample-cv", "pdf"))

        #expect(store.phase == .failed(.requestFailed(detail: "HTTP 429")))
        #expect(store.review == nil, "no review is offered")
        #expect(profileStore.profile?.roles.isEmpty == true, "the Profile is unchanged")
    }

    @Test("[CVIMPORT-17] a proposal validation failure carries the reason the proposal was rejected")
    func proposalValidationFailureCarriesTheReason() async throws {
        let profileStore = try makeProfileStore()

        // A missing required part…
        let missingRolesJSON = Data("""
        {
          "identity": {
            "name": "Alex Climber",
            "headline": null,
            "contact": { "email": null, "phone": null, "location": null, "link": null }
          },
          "notImportedSections": []
        }
        """.utf8)
        let missingRoles = makeImportStore(
            profileStore: profileStore,
            service: FixtureIntelligenceService(returning: missingRolesJSON)
        )
        await missingRoles.startImport(of: try fixtureURL("sample-cv", "pdf"))
        guard case .failed(.proposalInvalid(let reason)) = missingRoles.phase else {
            Issue.record("expected .failed(.proposalInvalid), got \(missingRoles.phase)")
            return
        }
        #expect(reason.contains("roles"), "the reason names the rejected part, got: \(reason)")

        // …and a response that isn't JSON at all.
        let notJSON = makeImportStore(
            profileStore: profileStore,
            service: FixtureIntelligenceService(returning: Data("Sorry, I can't help with that.".utf8))
        )
        await notJSON.startImport(of: try fixtureURL("sample-cv", "pdf"))
        guard case .failed(.proposalInvalid(let jsonReason)) = notJSON.phase else {
            Issue.record("expected .failed(.proposalInvalid), got \(notJSON.phase)")
            return
        }
        #expect(
            jsonReason.localizedCaseInsensitiveContains("json"),
            "a non-JSON response is named as such, got: \(jsonReason)"
        )
    }

    @Test("[CVIMPORT-18] a proposal wrapped in a markdown code fence produces a review")
    func fencedProposalProducesReview() async throws {
        let profileStore = try makeProfileStore()
        // The canned proposal, exactly as a live model fences it.
        let bareJSON = try Data(contentsOf: fixtureURL("import-proposal", "json"))
        let fenced = Data("```json\n\(String(decoding: bareJSON, as: UTF8.self))\n```".utf8)
        let store = makeImportStore(
            profileStore: profileStore,
            service: FixtureIntelligenceService(returning: fenced)
        )

        await store.startImport(of: try fixtureURL("sample-cv", "pdf"))

        #expect(store.phase == .review)
        let review = try #require(store.review)
        #expect(review.roles.map(\.proposed.company) == ["Acme", "Initech"], "the fenced proposal reads exactly as the bare one")
    }

    @Test("[CVIMPORT-19] a response cut off at the model's token limit fails the import with a truncation reason")
    func truncatedResponseFailsWithTruncationReason() async throws {
        let profileStore = try makeProfileStore()
        let store = ImportStore(
            profileStore: profileStore,
            keyStore: InMemoryAPIKeyStore(key: "test-key"),
            makeIntelligence: { _ in ThrowingIntelligenceService(error: .truncated) }
        )

        await store.startImport(of: try fixtureURL("sample-cv", "pdf"))

        #expect(store.phase == .failed(.responseTruncated))
        #expect(store.review == nil, "no review is offered")
        #expect(profileStore.profile?.roles.isEmpty == true, "the Profile is unchanged")
    }

    @Test("[CVIMPORT-19] the service throws truncated on a max_tokens stop, before returning any text")
    func serviceThrowsTruncatedOnMaxTokensStop() throws {
        // Truncated JSON must never reach proposal validation.
        let truncated = Data(
            #"{"content":[{"type":"text","text":"{\"roles\":[{\"compa"}],"stop_reason":"max_tokens"}"#.utf8
        )
        #expect(throws: AnthropicIntelligenceService.LiveServiceError.truncated) {
            try AnthropicIntelligenceService.responseText(from: truncated)
        }

        let complete = Data(
            #"{"content":[{"type":"text","text":"{}"}],"stop_reason":"end_turn"}"#.utf8
        )
        #expect(try AnthropicIntelligenceService.responseText(from: complete) == Data("{}".utf8))
    }
}

/// Fails every request the way the live service does.
private struct ThrowingIntelligenceService: IntelligenceService {
    var error: AnthropicIntelligenceService.LiveServiceError

    func complete(_ request: IntelligenceRequest) async throws -> Data {
        throw error
    }
}

/// The `makeIntelligence` factory runs on the main actor inside the store.
@MainActor
private final class KeyBox {
    var value: String?
}

/// Proposal dates are month-resolution UTC.
@MainActor
private func monthDate(_ year: Int, _ month: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar.date(from: components)!
}

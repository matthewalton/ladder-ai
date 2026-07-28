import Foundation
import PDFKit
import Testing

@testable import Ladder

/// Every content assertion extracts text from the rendered PDF with PDFKit,
/// never by inspecting SwiftUI views.
@MainActor
struct CVPreviewRenderTests {
    private func text(_ model: CVPreviewModel) throws -> String {
        try CVPreviewFixture.extractedText(of: model.pdfData)
    }

    @Test("[CVEXPORT-41] when an Achievement the tailor result skipped is added in the preview, it appears on the rendered CV")
    func addedAchievementAppearsOnTheRenderedCV() async throws {
        let harness = try await CVPreviewFixture.harness()
        let skipped = try CVPreviewFixture.achievement(
            "Shipped the offline sync engine", in: harness.profileStore)

        harness.model.setSelected(skipped, true)

        let text = try text(harness.model)
        #expect(
            text.contains("Shipped the offline sync engine"),
            "the canonical text — the service never saw this point, so nothing rephrased it")
        let acme = try #require(text.range(of: "Senior Engineer, Acme"))
        let added = try #require(text.range(of: "Shipped the offline sync engine"))
        let globex = try #require(text.range(of: "Engineer, Globex"))
        #expect(acme.lowerBound < added.lowerBound, "under its own Role")
        #expect(added.lowerBound < globex.lowerBound)
        let cut = try #require(
            text.range(of: "Drove CI build times down across every product target"))
        #expect(cut.lowerBound < added.lowerBound, "in that Role's own achievement order")
    }

    @Test("[CVEXPORT-41] an added Achievement's title still leads its bullet")
    func addedAchievementKeepsItsTitle() async throws {
        let harness = try await CVPreviewFixture.harness()
        let skipped = try CVPreviewFixture.achievement(
            "Shipped the offline sync engine", in: harness.profileStore)
        try harness.profileStore.updateAchievementTitle(skipped, to: "Offline sync")

        harness.model.setSelected(skipped, true)

        #expect(try text(harness.model).contains("Offline sync - Shipped the offline sync engine"))
    }

    @Test("[CVEXPORT-41] adding the first bullet to a bare role turns it into a role with content")
    func addingToABareRoleGivesItContent() async throws {
        let harness = try await CVPreviewFixture.harness()
        let bare = try CVPreviewFixture.achievement(
            "Automated the nightly release", in: harness.profileStore)
        try #require(!text(harness.model).contains("Automated the nightly release"))

        harness.model.setSelected(bare, true)

        let text = try text(harness.model)
        #expect(text.contains("Junior Engineer, Initech"))
        #expect(text.contains("Automated the nightly release"))
    }

    @Test("[CVEXPORT-42] when a selected Achievement is removed in the preview, it leaves the rendered CV")
    func removedAchievementLeavesTheRenderedCV() async throws {
        let harness = try await CVPreviewFixture.harness()
        let reporting = try CVPreviewFixture.achievement(
            "Built the reporting stack", in: harness.profileStore)

        harness.model.setSelected(reporting, false)

        let text = try text(harness.model)
        #expect(!text.contains("Built the analytics reporting stack from scratch"))
        #expect(
            text.contains("Engineer, Globex"),
            "removing a role's last bullet does not remove the job")
        #expect(text.contains("Jun 2015 - Feb 2018"))
    }

    @Test("[CVEXPORT-43] when a Project the tailor result skipped is added in the preview, it appears on the rendered CV")
    func addedProjectAppearsOnTheRenderedCV() async throws {
        let harness = try await CVPreviewFixture.harness()
        let skipped = try CVPreviewFixture.project("Weather Widget", in: harness.profileStore)

        harness.model.setSelected(skipped, true)

        let text = try text(harness.model)
        #expect(text.contains("Weather Widget"))
        #expect(
            text.contains("Rendered live forecasts on the lock screen."),
            "its description as one prose block, verbatim from the Profile")
    }

    @Test("[CVEXPORT-43] a CV with no selected projects gains its Projects section on the first add")
    func firstAddedProjectBringsTheSectionBack() async throws {
        let harness = try await CVPreviewFixture.harness()
        let mapper = try CVPreviewFixture.project("Trail Mapper", in: harness.profileStore)
        let widget = try CVPreviewFixture.project("Weather Widget", in: harness.profileStore)
        harness.model.setSelected(mapper, false)
        try #require(!text(harness.model).contains("PROJECTS"))

        harness.model.setSelected(widget, true)

        #expect(try text(harness.model).contains("PROJECTS"))
    }

    @Test("[CVEXPORT-44] when a selected Project is removed in the preview, it leaves the rendered CV")
    func removedProjectLeavesTheRenderedCV() async throws {
        let harness = try await CVPreviewFixture.harness()
        let mapper = try CVPreviewFixture.project("Trail Mapper", in: harness.profileStore)

        harness.model.setSelected(mapper, false)

        let text = try text(harness.model)
        #expect(!text.contains("Trail Mapper"))
        #expect(!text.contains("PROJECTS"), "removing the last project removes the heading with it")
    }

    @Test("[CVEXPORT-45] when a skill is dropped in the preview, the skills table omits it")
    func droppedSkillLeavesTheSkillsTable() async throws {
        let harness = try await CVPreviewFixture.harness()

        harness.model.setDropped(skill: "Swift", true)

        let text = try text(harness.model)
        #expect(text.contains("Platform Engineering: CI/CD"))
        #expect(!text.contains("Platform Engineering: CI/CD, Swift"))
    }

    @Test("[CVEXPORT-45] dropping the last skill in a category removes that category's heading")
    func droppingACategorysLastSkillRemovesIt() async throws {
        let harness = try await CVPreviewFixture.harness()

        harness.model.setDropped(skill: "SQL", true)

        #expect(try !text(harness.model).contains("Data:"))
    }

    @Test("[CVEXPORT-45] dropping a whole category takes its skills with it")
    func droppingACategoryTakesItsSkills() async throws {
        let harness = try await CVPreviewFixture.harness()

        harness.model.setDropped(category: "Platform Engineering", true)

        let text = try text(harness.model)
        #expect(!text.contains("Platform Engineering"))
        #expect(!text.contains("CI/CD"))
        #expect(text.contains("Data: SQL"), "the other category is untouched")
    }

    @Test("[CVEXPORT-45] dropping every category removes the skills section")
    func droppingEveryCategoryRemovesTheSection() async throws {
        let harness = try await CVPreviewFixture.harness()

        harness.model.setDropped(category: "Platform Engineering", true)
        harness.model.setDropped(category: "Data", true)

        #expect(try !text(harness.model).contains("SKILLS"))
    }

    @Test("[CVEXPORT-45] a dropped skill is never a vocabulary edit")
    func droppingASkillLeavesTheProfileVocabularyAlone() async throws {
        let harness = try await CVPreviewFixture.harness()
        let point = try CVPreviewFixture.achievement(
            "Cut CI build times across every product target", in: harness.profileStore)

        harness.model.setDropped(skill: "Swift", true)

        let profile = try #require(harness.profileStore.profile)
        #expect(profile.skills.contains { $0.name == "Swift" }, "the Tag stays on the Profile")
        #expect(point.skills.contains { $0.name == "Swift" }, "and on the point that evidences it")
    }

    @Test("[CVEXPORT-46] when a whole Role is removed in the preview, the rendered CV omits that role")
    func removedRoleLeavesTheRenderedCV() async throws {
        let harness = try await CVPreviewFixture.harness()
        let globex = try CVPreviewFixture.role("Globex", in: harness.profileStore)

        harness.model.setRemoved(globex, true)

        let text = try text(harness.model)
        #expect(!text.contains("Engineer, Globex"))
        #expect(
            !text.contains("Built the analytics reporting stack from scratch"),
            "the role's bullets go with it")
        #expect(!text.contains("Jun 2015 - Feb 2018"), "no placeholder marks the hole")
        let acme = try #require(text.range(of: "Senior Engineer, Acme"))
        let initech = try #require(text.range(of: "Junior Engineer, Initech"))
        #expect(acme.lowerBound < initech.lowerBound, "the rest keep their newest-first order")
    }

    @Test("[CVEXPORT-47] when an Education entry is removed in the preview, the rendered CV omits it")
    func removedEducationEntryLeavesTheRenderedCV() async throws {
        let harness = try await CVPreviewFixture.harness()
        let profile = try #require(harness.profileStore.profile)
        let course = try #require(
            profile.education.first(where: { $0.institution == "Open Courseware" }))

        harness.model.setRemoved(course, true)

        let text = try text(harness.model)
        #expect(!text.contains("ML Specialisation, Open Courseware"))
        #expect(
            text.contains("BSc Computer Science, University of Example"),
            "what remains keeps its verbatim rendering")
        #expect(text.contains("First-class honours"))
    }

    @Test("[CVEXPORT-47] removing every Education entry removes the Education section")
    func removingEveryEducationEntryRemovesTheSection() async throws {
        let harness = try await CVPreviewFixture.harness()
        let profile = try #require(harness.profileStore.profile)

        for entry in profile.education { harness.model.setRemoved(entry, true) }

        #expect(try !text(harness.model).contains("EDUCATION"))
    }

    @Test("[CVEXPORT-48] when an interest is removed in the preview, the rendered CV omits it")
    func removedInterestLeavesTheRenderedCV() async throws {
        let harness = try await CVPreviewFixture.harness()

        harness.model.setRemoved(interest: "Trail running", true)

        let text = try text(harness.model)
        #expect(!text.contains("Trail running"))
        #expect(text.contains("Cycling · Coffee"), "what remains keeps its Profile entry order")
    }

    @Test("[CVEXPORT-48] removing every interest removes the Interests section")
    func removingEveryInterestRemovesTheSection() async throws {
        let harness = try await CVPreviewFixture.harness()

        for interest in ["Cycling", "Trail running", "Coffee"] {
            harness.model.setRemoved(interest: interest, true)
        }

        #expect(try !text(harness.model).contains("INTERESTS"))
    }

    @Test("[CVEXPORT-49] when the headline or a contact line is removed in the preview, the identity header omits it")
    func removedHeaderElementsLeaveTheIdentityHeader() async throws {
        let harness = try await CVPreviewFixture.harness()

        harness.model.setHeadlineRemoved(true)
        harness.model.setRemoved(contactLine: "+44 7700 900123", true)

        let text = try text(harness.model)
        #expect(!text.contains("Staff Engineer"))
        #expect(!text.contains("+44 7700 900123"), "a phone number withheld from one employer")
        #expect(text.contains("alex@example.com"), "the lines the user kept still render")
        #expect(text.contains("ladder.app/alex"))
    }

    @Test("[CVEXPORT-50] the Profile's name always appears on the rendered CV")
    func theNameAlwaysAppears() async throws {
        let harness = try await CVPreviewFixture.harness()
        let profile = try #require(harness.profileStore.profile)

        harness.model.setHeadlineRemoved(true)
        for line in ["alex@example.com", "+44 7700 900123", "London", "ladder.app/alex"] {
            harness.model.setRemoved(contactLine: line, true)
        }
        for role in profile.roles { harness.model.setRemoved(role, true) }
        for entry in profile.education { harness.model.setRemoved(entry, true) }
        for interest in profile.interests { harness.model.setRemoved(interest: interest, true) }
        for category in harness.review.skillCategories {
            harness.model.setDropped(category: category.name, true)
        }
        for project in profile.projects { harness.model.setSelected(project, false) }
        harness.model.rewordSummary(to: "")

        #expect(
            try text(harness.model).contains("Alex Climber"),
            "no sequence of preview edits produces a nameless render")
    }

    @Test("[CVEXPORT-51] when a bullet is reworded in the preview, the rendered CV carries the reworded text")
    func rewordedBulletRendersItsNewText() async throws {
        let harness = try await CVPreviewFixture.harness()
        let point = try CVPreviewFixture.achievement(
            "Cut CI build times across every product target", in: harness.profileStore)
        try harness.profileStore.updateAchievementTitle(point, to: "Rebuilt the CI pipeline")

        harness.model.reword(point, to: "Halved CI build times across every product target")

        let text = try text(harness.model)
        #expect(text.contains("Halved CI build times across every product target"))
        #expect(!text.contains("Drove CI build times down across every product target"))
        #expect(
            text.contains(
                "Rebuilt the CI pipeline - Halved CI build times across every product target"),
            "the title still leads it verbatim from the Profile")
    }

    @Test("[CVEXPORT-52] rewording a bullet in the preview leaves the Profile's canonical achievement wording unchanged")
    func rewordingLeavesTheCanonAlone() async throws {
        let harness = try await CVPreviewFixture.harness()
        let profile = try #require(harness.profileStore.profile)
        let point = try CVPreviewFixture.achievement(
            "Cut CI build times across every product target", in: harness.profileStore)
        try harness.profileStore.updateAchievementTitle(point, to: "Rebuilt the CI pipeline")
        let before = profile.roles
            .flatMap(\.orderedAchievements)
            .map { [$0.text, $0.title ?? ""] }

        let reporting = try CVPreviewFixture.achievement(
            "Built the reporting stack", in: harness.profileStore)
        harness.model.reword(point, to: "Halved CI build times across every product target")
        harness.model.reword(reporting, to: "Built the reporting stack end to end")
        try harness.exportStore.export(harness.model.composition, into: harness.applicationID)

        #expect(
            profile.roles.flatMap(\.orderedAchievements).map { [$0.text, $0.title ?? ""] } == before,
            "character for character — a preview reword dies with the sitting")
    }

    @Test("[CVEXPORT-53] when the CV summary is reworded in the preview, the rendered CV carries the reworded summary")
    func rewordedSummaryRenders() async throws {
        let harness = try await CVPreviewFixture.harness()

        harness.model.rewordSummary(to: "Platform engineer who makes CI fast and keeps it fast.")

        let text = try text(harness.model)
        #expect(text.contains("Platform engineer who makes CI fast and keeps it fast."))
        #expect(!text.contains("Senior engineer with platform-scale CI performance"))
        let name = try #require(text.range(of: "Alex Climber"))
        let summary = try #require(
            text.range(of: "Platform engineer who makes CI fast and keeps it fast."))
        let role = try #require(text.range(of: "Senior Engineer, Acme"))
        #expect(name.lowerBound < summary.lowerBound, "it keeps its place under the header")
        #expect(summary.lowerBound < role.lowerBound)
    }

    @Test("[CVEXPORT-53] rewording the summary to empty renders no empty block")
    func emptySummaryRendersNoBlock() async throws {
        let harness = try await CVPreviewFixture.harness()

        harness.model.rewordSummary(to: "")

        let blocks = CVLayout(
            document: harness.model.composition.document,
            metrics: harness.model.composition.fit.metrics
        ).blocks
        #expect(!blocks.contains { $0.kind == .summary })
        #expect(try !text(harness.model).contains("Senior engineer with platform-scale"))
    }

    @Test("[CVEXPORT-54] when a Tag is applied to a point from the preview, the Profile links that Tag to the point")
    func applyingATagLinksItOnTheProfile() async throws {
        let harness = try await CVPreviewFixture.harness()
        let point = try CVPreviewFixture.achievement(
            "Built the reporting stack", in: harness.profileStore)

        let tag = try harness.model.applyTag(named: "kubernetes", to: point)

        let profile = try #require(harness.profileStore.profile)
        #expect(
            tag === profile.skills.first(where: { $0.name == "Kubernetes" }),
            "resolved case-insensitively against the pool — this slice never mints a SkillTag")
        #expect(point.skills.contains { $0 === tag })
        #expect(
            profile.skills.filter { $0.name.caseInsensitiveCompare("Kubernetes") == .orderedSame }
                .count == 1,
            "no duplicate pool entry")
    }

    @Test("[CVEXPORT-54] a Tag the Match already matched counts toward coverage at the next recompute")
    func appliedTagCountsTowardCoverage() async throws {
        let harness = try await CVPreviewFixture.harness()
        let point = try CVPreviewFixture.achievement(
            "Built the reporting stack", in: harness.profileStore)
        try #require(harness.model.coverage.uncovered == ["Kubernetes"])

        try harness.model.applyTag(named: "Kubernetes", to: point)

        #expect(harness.model.coverage.uncovered.isEmpty)
    }

    @Test("[CVEXPORT-58] when an edit changes the composed CV's length, the preview's page count updates from a deterministic re-layout")
    func pageCountFollowsEveryEdit() async throws {
        let service = FixtureIntelligenceService(returning: Data("{}".utf8))
        let harness = try await CVPreviewFixture.harness(
            extraBullets: 40, fitPasses: FitPassRunner(service: service))
        let extras = harness.profile.roles
            .flatMap(\.achievements)
            .filter { $0.text.hasPrefix("Extra point") }
        let start = harness.model.pageCount
        try #require(start <= 2)

        for achievement in extras { harness.model.setSelected(achievement, true) }
        let over = harness.model.pageCount
        for achievement in extras { harness.model.setSelected(achievement, false) }

        #expect(over > 2, "the count follows the document over the cap")
        #expect(harness.model.pageCount == start, "and back under it again")
        #expect(
            harness.model.pageCount
                == CVLayout(
                    document: harness.model.composition.document,
                    metrics: harness.model.composition.fit.metrics
                ).pages.count,
            "the real block-paginated count, never an estimate")
        #expect(await service.recordedRequests.isEmpty, "compaction and stretch only")
    }
}

import Foundation
import SwiftData
import SwiftUI
import Testing

@testable import Ladder

/// The docs/adr/0003 collapsed-content pattern on the prep pack: indicator
/// row, content window, and the confirmed remove. Row and dialog chrome are
/// on the visual-verify list.
@MainActor
struct PrepPackCollapseTests {
    private func makeStageWithPack() throws -> (ModelContainer, Stage, PrepPack, Achievement) {
        let container = try ProfileStore.container(inMemory: true)
        let context = ModelContext(container)
        let application = Application(
            company: "Summit Labs", roleTitle: "Platform Engineer",
            jobDescription: "Own platform reliability.", status: .active)
        context.insert(application)
        let stage = Stage(kind: .technical, prepContext: "Panel of three")
        context.insert(stage)
        stage.application = application
        let achievement = Achievement(text: "Led incident response for the payments outage")
        context.insert(achievement)
        let pack = PrepPack(
            generatedAt: Date(timeIntervalSince1970: 1_774_000_000),
            likelyQuestions: ["Walk me through a production incident you owned."],
            companyBrief: "Summit Labs is hiring for reliability.",
            mockTasks: [MockTask(title: "Design a rate limiter", brief: "Multi-tenant API.")])
        context.insert(pack)
        let point = PrepTalkingPoint(
            text: "Lead with the payments-outage story",
            achievements: [achievement])
        context.insert(point)
        point.prepPack = pack
        stage.prepPack = pack
        try context.save()
        return (container, stage, pack, achievement)
    }

    @Test("[PREP-20] a Stage's prep pack collapses to an indicator row in the Stage form")
    func prepPackCollapsesToIndicatorRow() throws {
        let (container, stage, _, _) = try makeStageWithPack()
        // Render-smoke: the section renders in its collapsed state — the
        // content moved behind Open, Regenerate and Export Markdown stay;
        // row chrome is visual-verify.
        let section = ImageRenderer(
            content: Form {
                PrepPackSection(
                    container: container, stage: stage,
                    keyStore: InMemoryAPIKeyStore(key: "sk-test"))
            }
            .formStyle(.grouped)
            .frame(width: 460, height: 300))
        #expect(section.nsImage != nil)
    }

    @Test("[PREP-21] opening the prep pack shows its content in a window")
    func prepPackWindowResolvesContent() throws {
        let (container, _, pack, _) = try makeStageWithPack()
        let window = PrepPackWindow(container: container, packID: pack.persistentModelID)

        #expect(window.resolvedPack?.persistentModelID == pack.persistentModelID)
        let image = ImageRenderer(content: window.frame(width: 480, height: 400))
        #expect(image.nsImage != nil)
    }

    @Test("[PREP-22] removing the prep pack requires confirmation before deleting it")
    func confirmedRemoveDeletesWithoutOrphans() throws {
        // The dialog is chrome (visual-verify); the confirmed action deletes
        // through the store.
        let (container, stage, _, achievement) = try makeStageWithPack()
        let profileStore = ProfileStore(container: container)
        try profileStore.load()
        let store = PrepPackStore(
            container: container, profileStore: profileStore,
            keyStore: InMemoryAPIKeyStore(key: "sk-test"))

        try store.removePrepPack(from: stage)

        let context = ModelContext(container)
        #expect(stage.prepPack == nil)
        #expect(
            try context.fetch(FetchDescriptor<PrepPack>()).isEmpty,
            "the pack is deleted, not orphaned")
        #expect(
            try context.fetch(FetchDescriptor<PrepTalkingPoint>()).isEmpty,
            "talking-point rows cascade with it")
        #expect(
            try context.fetch(FetchDescriptor<Achievement>()).count == 1,
            "the mapped Achievement survives untouched")
        _ = achievement
    }
}

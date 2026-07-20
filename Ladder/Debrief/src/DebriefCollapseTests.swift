import Foundation
import SwiftData
import SwiftUI
import Testing

@testable import Ladder

/// The docs/adr/0003 collapsed-content pattern on the debrief: indicator
/// row, content window, and the confirmed remove. Row and dialog chrome are
/// on the visual-verify list.
@MainActor
struct DebriefCollapseTests {
    private func makeStageWithDebrief() throws -> (ModelContainer, Stage, Debrief, Achievement) {
        let container = try ProfileStore.container(inMemory: true)
        let context = ModelContext(container)
        let stage = Stage(kind: .technical)
        context.insert(stage)
        let ammo = Achievement(text: "Led incident response for the payments outage")
        context.insert(ammo)
        let debrief = Debrief(
            generatedAt: Date(timeIntervalSince1970: 1_774_000_000),
            themes: [GroundedRemark(text: "Reliability throughout", quote: "incident timeline")],
            drills: ["Rehearse the outage story"])
        context.insert(debrief)
        let question = DebriefQuestion(
            question: "How did you handle the payments outage?",
            answerSummary: "Walked the timeline but never claimed the lead",
            quality: .adequate,
            quote: "incident timeline",
            missedAmmo: [ammo])
        context.insert(question)
        question.debrief = debrief
        stage.debrief = debrief
        try context.save()
        return (container, stage, debrief, ammo)
    }

    @Test("[DEBRIEF-18] a Stage's debrief collapses to an indicator row in the Stage form")
    func debriefCollapsesToIndicatorRow() throws {
        let (container, stage, _, _) = try makeStageWithDebrief()
        // Render-smoke: the section renders in its collapsed state — the
        // content moved behind Open; row chrome is visual-verify.
        let section = ImageRenderer(
            content: Form {
                DebriefSection(
                    container: container, stage: stage,
                    keyStore: InMemoryAPIKeyStore(key: "sk-test"))
            }
            .formStyle(.grouped)
            .frame(width: 460, height: 300))
        #expect(section.nsImage != nil)
    }

    @Test("[DEBRIEF-19] opening the debrief shows its content in a window")
    func debriefWindowResolvesContent() throws {
        let (container, _, debrief, _) = try makeStageWithDebrief()
        let window = DebriefWindow(container: container, debriefID: debrief.persistentModelID)

        #expect(window.resolvedDebrief?.persistentModelID == debrief.persistentModelID)
        let image = ImageRenderer(content: window.frame(width: 480, height: 400))
        #expect(image.nsImage != nil)
    }

    @Test("[DEBRIEF-20] removing the debrief requires confirmation before deleting it")
    func confirmedRemoveDeletesWithoutOrphans() throws {
        // The dialog is chrome (visual-verify); the confirmed action deletes
        // through the store.
        let (container, stage, _, ammo) = try makeStageWithDebrief()
        let profileStore = ProfileStore(container: container)
        try profileStore.load()
        let store = DebriefStore(
            container: container, profileStore: profileStore,
            keyStore: InMemoryAPIKeyStore(key: "sk-test"))

        try store.removeDebrief(from: stage)

        let context = ModelContext(container)
        #expect(stage.debrief == nil)
        #expect(
            try context.fetch(FetchDescriptor<Debrief>()).isEmpty,
            "the debrief is deleted, not orphaned")
        #expect(
            try context.fetch(FetchDescriptor<DebriefQuestion>()).isEmpty,
            "question entries cascade with it")
        #expect(
            try context.fetch(FetchDescriptor<Achievement>()).count == 1,
            "the missed-ammo Achievement survives untouched")
        _ = ammo
    }
}

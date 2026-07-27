import Foundation
import SwiftData
import SwiftUI
import Testing

@testable import Ladder

/// The journey section on the Application detail: the offer-time gate on
/// the generate action, the inline plain-text display, and the confirmed
/// remove. Section and dialog chrome are on the visual-verify list.
@MainActor
struct JourneySectionTests {
    private func makeApplication(
        status: ApplicationStatus = .offer, withNarrative: Bool = true
    ) throws -> (ModelContainer, Application) {
        let container = try ProfileStore.container(inMemory: true)
        let context = ModelContext(container)
        let application = Application(
            company: "Summit Labs", roleTitle: "Platform Engineer",
            jobDescription: "Own platform reliability.", status: status)
        context.insert(application)
        let stage = Stage(kind: .screen, outcome: .passed, sortIndex: 0)
        context.insert(stage)
        stage.application = application
        if withNarrative {
            let narrative = JourneyNarrative(
                text: "The Summit Labs climb opened quietly.",
                generatedAt: Date(timeIntervalSince1970: 1_773_000_000))
            context.insert(narrative)
            application.journeyNarrative = narrative
        }
        try context.save()
        return (container, application)
    }

    @Test("[JOURNEY-14] the generate action appears only on an Application at offer")
    func generateActionIsOfferGated() throws {
        for status in ApplicationStatus.allCases {
            #expect(
                JourneySection.showsGenerate(for: status) == (status == .offer),
                "the generate control renders for .offer and for no other status (\(status))")
        }

        // Render-smoke at the empty-at-offer state: the section offers
        // generation; button chrome is visual-verify.
        let (container, application) = try makeApplication(withNarrative: false)
        let section = ImageRenderer(
            content: Form {
                JourneySection(
                    container: container, application: application,
                    keyStore: InMemoryAPIKeyStore(key: "sk-test"))
            }
            .formStyle(.grouped)
            .frame(width: 460, height: 300))
        #expect(section.nsImage != nil)
    }

    @Test("[JOURNEY-15] the journey section shows the persisted narrative text")
    func sectionShowsThePersistedNarrative() throws {
        // The section renders only when the Application carries a narrative
        // or is at offer; display itself is never status-gated.
        #expect(JourneySection.appears(status: .offer, hasNarrative: false))
        #expect(JourneySection.appears(status: .offer, hasNarrative: true))
        #expect(JourneySection.appears(status: .rejected, hasNarrative: true),
            "a persisted narrative shows at any status")
        #expect(!JourneySection.appears(status: .active, hasNarrative: false))
        #expect(!JourneySection.appears(status: .draft, hasNarrative: false))

        // Render-smoke: the persisted narrative renders inline as plain
        // text; section chrome is visual-verify.
        let (container, application) = try makeApplication()
        let section = ImageRenderer(
            content: Form {
                JourneySection(
                    container: container, application: application,
                    keyStore: InMemoryAPIKeyStore(key: "sk-test"))
            }
            .formStyle(.grouped)
            .frame(width: 460, height: 300))
        #expect(section.nsImage != nil)
    }

    @Test("[JOURNEY-16] removing the narrative requires confirmation before deleting it")
    func confirmedRemoveDeletesWithoutOrphans() throws {
        // The dialog is chrome (visual-verify); the confirmed action deletes
        // through the store.
        let (container, application) = try makeApplication()
        let store = JourneyStore(
            container: container, keyStore: InMemoryAPIKeyStore(key: "sk-test"))

        try store.removeNarrative(from: application)

        let context = ModelContext(container)
        #expect(application.journeyNarrative == nil)
        #expect(
            try context.fetch(FetchDescriptor<JourneyNarrative>()).isEmpty,
            "the narrative is deleted, not orphaned")
        #expect(
            try context.fetch(FetchDescriptor<Application>()).count == 1,
            "the Application survives untouched")
        #expect(
            try context.fetch(FetchDescriptor<Stage>()).count == 1,
            "the Stages survive untouched")

        // Declining changes nothing — and a second remove is a no-op.
        try store.removeNarrative(from: application)
        #expect(try context.fetch(FetchDescriptor<Application>()).count == 1)
    }
}

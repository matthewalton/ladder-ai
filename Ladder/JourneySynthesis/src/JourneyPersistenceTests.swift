import Foundation
import SwiftData
import Testing

@testable import Ladder

@MainActor
struct JourneyPersistenceTests {
    private func makeApplication(in context: ModelContext) throws -> Application {
        let application = Application(
            company: "Summit Labs", roleTitle: "Platform Engineer",
            jobDescription: "Own platform reliability.", status: .offer,
            appliedAt: Date(timeIntervalSince1970: 1_770_100_000))
        context.insert(application)
        let stage = Stage(kind: .screen, sortIndex: 0)
        context.insert(stage)
        stage.application = application
        try context.save()
        return application
    }

    private func attachNarrative(
        to application: Application, in context: ModelContext
    ) throws -> JourneyNarrative {
        let narrative = JourneyNarrative(
            text: "The Summit Labs climb opened quietly.\n\nForty-one days later, the offer arrived.",
            generatedAt: Date(timeIntervalSince1970: 1_773_000_000))
        context.insert(narrative)
        application.journeyNarrative = narrative
        try context.save()
        return narrative
    }

    @Test("[JOURNEY-2] a fully-populated JourneyNarrative round-trips through a store reopen")
    func fullyPopulatedNarrativeRoundTrips() throws {
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }

        do {
            let container = try ProfileStore.container(at: url)
            let context = ModelContext(container)
            let application = try makeApplication(in: context)
            _ = try attachNarrative(to: application, in: context)
        }

        let reopened = try ProfileStore.container(at: url)
        let context = ModelContext(reopened)
        let narrative = try #require(try context.fetch(FetchDescriptor<JourneyNarrative>()).first)
        #expect(
            narrative.text
                == "The Summit Labs climb opened quietly.\n\nForty-one days later, the offer arrived.",
            "the text round-trips field-for-field, paragraph breaks included")
        #expect(narrative.generatedAt == Date(timeIntervalSince1970: 1_773_000_000))
        #expect(narrative.application?.company == "Summit Labs")
    }

    @Test("[JOURNEY-3] deleting an Application deletes its journey narrative with it")
    func deletingApplicationCascadesToNarrative() throws {
        let container = try ProfileStore.container(inMemory: true)
        let context = ModelContext(container)
        let application = try makeApplication(in: context)
        _ = try attachNarrative(to: application, in: context)

        context.delete(application)
        try context.save()

        #expect(
            try context.fetch(FetchDescriptor<JourneyNarrative>()).isEmpty,
            "no orphaned JourneyNarrative survives")
    }
}

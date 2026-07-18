import Foundation
import SwiftData
import Testing

@testable import Ladder

/// The slice's persistence criterion: dismissals are forever
/// (decisions/0004) — each test relaunches by closing one container and
/// reopening a new one against the same store URL (the [PROFILE-1] pattern).
@MainActor
struct CalendarSyncPersistenceTests {
    @Test("[CALSYNC-12] a dismissal survives an app relaunch")
    func dismissalSurvivesRelaunch() async throws {
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }
        let now = CalendarSyncFlowTests.now
        let events = [
            CalendarEvent(
                identifier: "evt-1", title: "Acme screen",
                start: now.addingTimeInterval(86_400)
            )
        ]

        do {
            let pipeline = PipelineStore(container: try ProfileStore.container(at: url))
            let context = ModelContext(pipeline.container)
            context.insert(
                Application(
                    company: "Acme", roleTitle: "Engineer", jobDescription: "JD",
                    status: .applied, appliedAt: now
                )
            )
            try context.save()
            try pipeline.load()
            let sync = CalendarSyncStore(
                pipeline: pipeline,
                service: FixtureCalendarSyncService(events: events)
            )
            await sync.scan(asOf: now)
            let proposal = try #require(sync.proposals.first)
            try sync.dismiss(proposal, asOf: now)
        }

        let pipeline = PipelineStore(container: try ProfileStore.container(at: url))
        try pipeline.load()
        let records = try ModelContext(pipeline.container)
            .fetch(FetchDescriptor<DismissedEvent>())
        #expect(records.map(\.calendarEventID) == ["evt-1"])

        // And the reopened store still suppresses the event.
        let sync = CalendarSyncStore(
            pipeline: pipeline,
            service: FixtureCalendarSyncService(events: events)
        )
        await sync.scan(asOf: now)
        #expect(sync.scanState == .ready)
        #expect(sync.proposals.isEmpty)
    }
}

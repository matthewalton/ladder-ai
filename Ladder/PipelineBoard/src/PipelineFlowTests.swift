import Foundation
import SwiftData
import SwiftUI
import Testing

@testable import Ladder

/// The board's behaviour criteria, unit-tested against `PipelineStore` on an
/// in-memory container (slice AGENTS.md): grouping, the transition map,
/// stamping, auto-advance, cascade, and the card derivations.
@MainActor
struct PipelineFlowTests {
    private func makeStore() throws -> PipelineStore {
        try PipelineStore(container: ProfileStore.container(inMemory: true))
    }

    @discardableResult
    private func insert(
        _ store: PipelineStore,
        company: String,
        status: ApplicationStatus,
        appliedAt: Date? = nil,
        createdAt: Date = Date(timeIntervalSince1970: 1_770_000_000)
    ) throws -> Application {
        let application = Application(
            company: company, roleTitle: "Engineer", jobDescription: "JD",
            status: status, appliedAt: appliedAt, createdAt: createdAt
        )
        let context = ModelContext(store.container)
        context.insert(application)
        try context.save()
        try store.load()
        return application
    }

    @Test("[PIPEBOARD-4] the board shows each Application in the column matching its status")
    func columnsGroupByStatus() throws {
        let store = try makeStore()
        try insert(store, company: "Draft Co", status: .draft)
        let older = try insert(
            store, company: "Applied Older", status: .applied,
            appliedAt: Date(timeIntervalSince1970: 1_770_000_000))
        let newer = try insert(
            store, company: "Applied Newer", status: .applied,
            appliedAt: Date(timeIntervalSince1970: 1_770_500_000))
        try insert(store, company: "Offer Co", status: .offer)

        #expect(store.applications(in: .draft).map(\.company) == ["Draft Co"])
        #expect(store.applications(in: .offer).map(\.company) == ["Offer Co"])
        #expect(store.applications(in: .active).isEmpty)
        #expect(store.applications(in: .rejected).isEmpty)
        #expect(store.applications(in: .withdrawn).isEmpty)
        #expect(
            store.applications(in: .applied).map(\.company) == ["Applied Newer", "Applied Older"],
            "newest-first by applied date falling back to creation date"
        )
        #expect(older.appliedAt != nil && newer.appliedAt != nil)
    }

    @Test("[PIPEBOARD-5] moving an Application along a legal transition updates its persisted status")
    func legalMovePersistsNewStatus() throws {
        let store = try makeStore()
        try insert(store, company: "Summit Labs", status: .applied)

        let application = try #require(store.applications(in: .applied).first)
        try store.move(application, to: .active)

        #expect(store.applications(in: .active).map(\.company) == ["Summit Labs"])
        // A fresh context sees the saved status — the mutation persisted.
        let fresh = ModelContext(store.container)
        let persisted = try #require(try fresh.fetch(FetchDescriptor<Application>()).first)
        #expect(persisted.status == .active)
    }

    @Test("[PIPEBOARD-5] a same-status drop is a no-op")
    func sameStatusMoveIsNoOp() throws {
        let store = try makeStore()
        try insert(store, company: "Summit Labs", status: .applied)

        let application = try #require(store.applications(in: .applied).first)
        try store.move(application, to: .applied)

        #expect(application.status == .applied)
    }

    @Test(
        "[PIPEBOARD-6] moving an Application along an illegal transition leaves its status unchanged",
        arguments: [
            (ApplicationStatus.rejected, ApplicationStatus.offer),
            (.applied, .draft),
            (.withdrawn, .applied),
            (.offer, .active),
            (.draft, .active),
        ]
    )
    func illegalMoveIsRefused(from: ApplicationStatus, to: ApplicationStatus) throws {
        let store = try makeStore()
        try insert(store, company: "Summit Labs", status: from)
        let application = try #require(store.applications(in: from).first)

        #expect(throws: PipelineStoreError.illegalTransition(from: from, to: to)) {
            try store.move(application, to: to)
        }
        #expect(application.status == from, "a refused move changes nothing")
        #expect(PipelineStore.canMove(from: from, to: to) == false, "the board never offers this target")
    }

    @Test("[PIPEBOARD-7] adding the first Stage to an applied Application advances it to active")
    func firstStageAutoAdvancesAppliedToActive() throws {
        let store = try makeStore()
        try insert(store, company: "Summit Labs", status: .applied)
        let application = try #require(store.applications(in: .applied).first)

        try store.addStage(to: application, kind: .screen)
        #expect(application.status == .active, "an interview loop starting is the application going active")

        try store.addStage(to: application, kind: .technical)
        #expect(application.status == .active, "only the first Stage auto-advances")
    }

    @Test(
        "[PIPEBOARD-7] adding a Stage in any other status changes no status",
        arguments: [ApplicationStatus.draft, .active, .offer, .rejected, .withdrawn]
    )
    func stageInOtherStatusesLeavesStatusAlone(status: ApplicationStatus) throws {
        let store = try makeStore()
        try insert(store, company: "Summit Labs", status: status)
        let application = try #require(store.applications(in: status).first)

        try store.addStage(to: application, kind: .screen)

        #expect(application.status == status)
    }

    @Test("[PIPEBOARD-9] moving a draft Application to applied stamps its applied date")
    func draftToAppliedStampsAppliedDate() throws {
        let store = try makeStore()
        try insert(store, company: "Summit Labs", status: .draft)
        let application = try #require(store.applications(in: .draft).first)
        #expect(application.appliedAt == nil)

        try store.move(application, to: .applied)

        #expect(application.appliedAt != nil, "applying is the moment the date records")
    }

    @Test("[PIPEBOARD-9] an existing applied date is never overwritten by a move")
    func existingAppliedDateSurvivesMove() throws {
        let store = try makeStore()
        let ownDate = Date(timeIntervalSince1970: 1_770_900_000)
        try insert(store, company: "Summit Labs", status: .draft, appliedAt: ownDate)
        let application = try #require(store.applications(in: .draft).first)

        try store.move(application, to: .applied)

        #expect(application.appliedAt == ownDate)
    }

    @Test("[PIPEBOARD-11] deleting an Application removes its Stages with it")
    func deletingApplicationCascadesToStages() throws {
        let store = try makeStore()
        try insert(store, company: "Summit Labs", status: .active)
        let application = try #require(store.applications(in: .active).first)
        let first = try store.addStage(to: application, kind: .screen)
        try store.addStage(to: application, kind: .technical)
        try store.addStage(to: application, kind: .final)

        // First act: deleting a single Stage removes just that Stage.
        try store.deleteStage(first)
        let context = ModelContext(store.container)
        #expect(try context.fetch(FetchDescriptor<Stage>()).count == 2)
        #expect(application.orderedStages.map(\.kind) == [.technical, .final])

        // Then the cascade: no orphaned Stages survive their Application.
        try store.deleteApplication(application)
        #expect(try context.fetch(FetchDescriptor<Application>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Stage>()).isEmpty, "no orphans")
    }

    @Test("[PIPEBOARD-13] an application card derives its next waypoint from its earliest pending Stage")
    func nextWaypointIsEarliestPendingStage() throws {
        let store = try makeStore()
        try insert(store, company: "Summit Labs", status: .active)
        let application = try #require(store.applications(in: .active).first)

        #expect(PipelineStore.nextWaypoint(for: application) == nil, "no Stages, no waypoint chip")

        let screen = try store.addStage(to: application, kind: .screen)
        try store.addStage(to: application, kind: .technical)
        #expect(PipelineStore.nextWaypoint(for: application) == .screen)

        // The screen resolving hands the waypoint to the next pending Stage.
        screen.outcome = .passed
        #expect(PipelineStore.nextWaypoint(for: application) == .technical)

        let technical = try #require(application.orderedStages.last)
        technical.outcome = .failed
        #expect(PipelineStore.nextWaypoint(for: application) == nil, "no pending Stage, no waypoint")
    }

    @Test("[PIPEBOARD-16] an application card derives its days on trail from its applied date")
    func daysOnTrailCountFromAppliedDate() throws {
        let store = try makeStore()
        let appliedAt = Date(timeIntervalSince1970: 1_770_000_000)
        let applied = try insert(
            store, company: "Has Applied Date", status: .active, appliedAt: appliedAt)
        let draftOnly = try insert(
            store, company: "Draft", status: .draft,
            createdAt: Date(timeIntervalSince1970: 1_770_000_000))

        let twelveDaysLater = appliedAt.addingTimeInterval(12 * 86_400)
        #expect(PipelineStore.daysOnTrail(for: applied, asOf: twelveDaysLater) == 12)
        #expect(
            PipelineStore.daysOnTrail(for: applied, asOf: appliedAt.addingTimeInterval(3_600)) == 0,
            "whole days — the first day on trail is day zero"
        )
        #expect(
            PipelineStore.daysOnTrail(for: draftOnly, asOf: twelveDaysLater) == 12,
            "no applied date falls back to the creation date"
        )
    }

    @Test("[PIPEBOARD-14] the app shell switches between the Profile and Applications sections")
    func shellOffersBothSectionRoots() throws {
        #expect(AppSection.allCases == [.profile, .applications], "the shell offers exactly these sections")

        let profileStore = try ProfileStore(container: ProfileStore.container(inMemory: true))
        try profileStore.load()
        let pipelineStore = PipelineStore(container: profileStore.container)
        try pipelineStore.load()

        // Both section roots render — the same views the shell's TabView
        // switches between; native tab feel is on the visual-verify list.
        let profileRoot = ImageRenderer(
            content: ProfileRootView(store: profileStore).frame(width: 480, height: 320))
        #expect(profileRoot.nsImage != nil, "the Profile section root renders")
        let applicationsRoot = ImageRenderer(
            content: PipelineRootView(store: pipelineStore).frame(width: 480, height: 320))
        #expect(applicationsRoot.nsImage != nil, "the Applications section root renders")
    }
}

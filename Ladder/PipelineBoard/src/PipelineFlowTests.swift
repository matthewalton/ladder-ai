import Foundation
import SwiftData
import SwiftUI
import Testing

@testable import Ladder

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

    @Test("[PIPEBOARD-17] manually adding an applied Application persists it with the chosen applied date")
    func manualAppliedAddPersistsChosenDate() throws {
        let store = try makeStore()
        try store.load()
        let backdated = Date(timeIntervalSince1970: 1_769_000_000)

        let created = try store.createApplication(
            company: "Summit Labs", roleTitle: "Platform Engineer",
            source: "Referral", notes: "Met them at SwiftConf", appliedAt: backdated
        )

        #expect(created.status == .applied)
        #expect(created.appliedAt == backdated, "backdating is allowed — the chosen date, not .now")
        #expect(created.source == "Referral")
        #expect(created.notes == "Met them at SwiftConf")
        #expect(created.jobDescription.isEmpty)
        #expect(created.cvSnapshot == nil, "export stays the only path that attaches a CV")
        #expect(created.cvSelectionRationale == nil)
        #expect(
            store.applications(in: .applied).map(\.company) == ["Summit Labs"],
            "the board sees the manual add without a reload"
        )
        // A fresh context sees the saved row — creation persisted.
        let fresh = ModelContext(store.container)
        let persisted = try #require(try fresh.fetch(FetchDescriptor<Application>()).first)
        #expect(persisted.appliedAt == backdated)
    }

    @Test("[PIPEBOARD-18] manually adding a draft Application leaves its applied date unset")
    func manualDraftAddLeavesAppliedDateUnset() throws {
        let store = try makeStore()
        try store.load()

        let created = try store.createApplication(
            company: "Summit Labs", roleTitle: "Platform Engineer",
            source: nil, notes: "", appliedAt: nil
        )

        #expect(created.status == .draft)
        #expect(created.appliedAt == nil, "the draft → applied move stamps it later ([PIPEBOARD-9])")
        #expect(store.applications(in: .draft).map(\.company) == ["Summit Labs"])
    }

    @Test("[PIPEBOARD-19] a manual add with a blank company or role title is refused")
    func blankManualAddIsRefused() throws {
        let store = try makeStore()
        try store.load()

        #expect(throws: PipelineStoreError.blankField) {
            try store.createApplication(
                company: "", roleTitle: "Engineer", source: nil, notes: "", appliedAt: .now)
        }
        #expect(throws: PipelineStoreError.blankField) {
            try store.createApplication(
                company: "Summit Labs", roleTitle: "   ", source: nil, notes: "", appliedAt: .now)
        }
        #expect(store.applications.isEmpty, "a refused add persists nothing")
        let fresh = ModelContext(store.container)
        #expect(try fresh.fetch(FetchDescriptor<Application>()).isEmpty)

        // No dedup: the same company and role twice is two Applications.
        try store.createApplication(
            company: "Summit Labs", roleTitle: "Engineer", source: nil, notes: "", appliedAt: .now)
        try store.createApplication(
            company: "Summit Labs", roleTitle: "Engineer", source: nil, notes: "", appliedAt: .now)
        #expect(store.applications.count == 2)
    }

    @Test("[PIPEBOARD-20] the add-application form opens from the empty state and the shell toolbar")
    func addFormRendersFromBothHosts() throws {
        // Render-smoke only: chrome and sheet presentation are on the
        // visual-verify list.
        let emptyStore = try makeStore()
        try emptyStore.load()
        let emptyRoot = ImageRenderer(
            content: PipelineRootView(store: emptyStore).frame(width: 800, height: 500))
        #expect(emptyRoot.nsImage != nil, "the empty state renders with its add action")

        let populatedStore = try makeStore()
        try insert(populatedStore, company: "Summit Labs", status: .applied)
        let populatedRoot = ImageRenderer(
            content: PipelineRootView(store: populatedStore).frame(width: 800, height: 500))
        #expect(populatedRoot.nsImage != nil, "the shell renders with its toolbar")

        let form = ImageRenderer(
            content: AddApplicationSheet(store: emptyStore).frame(width: 420, height: 420))
        #expect(form.nsImage != nil, "the add-application form renders")
    }

    @Test("[PIPEBOARD-34] the tailor sheet opens from the empty state and the Applications shell toolbar")
    func tailorEntryRendersFromBothHosts() throws {
        // Render-smoke only, the [PIPEBOARD-20] stance: chrome and sheet
        // presentation are on the visual-verify list.
        let profileStore = try ProfileStore(container: ProfileStore.container(inMemory: true))
        try profileStore.load()
        try profileStore.createProfile(name: "Alex Climber", headline: "Staff Engineer")
        let pipelineStore = PipelineStore(container: profileStore.container)
        try pipelineStore.load()

        let emptyRoot = ImageRenderer(
            content: PipelineRootView(store: pipelineStore, profileStore: profileStore)
                .frame(width: 800, height: 500))
        #expect(emptyRoot.nsImage != nil, "the empty state renders with its tailor action")

        let role = try profileStore.addRole(company: "Acme", title: "Engineer", start: .now, end: nil)
        try profileStore.addAchievement(to: role, text: "Cut CI build times")
        let populated = try makeStore()
        try insert(populated, company: "Summit Labs", status: .applied)
        let populatedRoot = ImageRenderer(
            content: PipelineRootView(store: populated, profileStore: profileStore)
                .frame(width: 800, height: 500))
        #expect(populatedRoot.nsImage != nil, "the shell renders with its tailor toolbar button")

        let sheet = ImageRenderer(
            content: TailorView(
                profileStore: profileStore,
                keyStore: InMemoryAPIKeyStore(key: "test-key"),
                makeIntelligence: { _ in FixtureIntelligenceService.tailorFixture() }
            ).frame(width: 560, height: 480))
        #expect(sheet.nsImage != nil, "the tailor sheet renders from this shell's hosting")
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

        // Render-smoke only: native tab feel is on the visual-verify list.
        let profileRoot = ImageRenderer(
            content: ProfileRootView(store: profileStore).frame(width: 480, height: 320))
        #expect(profileRoot.nsImage != nil, "the Profile section root renders")
        let applicationsRoot = ImageRenderer(
            content: PipelineRootView(store: pipelineStore).frame(width: 480, height: 320))
        #expect(applicationsRoot.nsImage != nil, "the Applications section root renders")
    }
}

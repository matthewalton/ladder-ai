import Foundation
import SwiftData
import SwiftUI
import Testing

@testable import Ladder

@MainActor
struct TimelineFlowTests {
    @Test("[TIMELINE-1] the timeline for an applied Application begins with its applied entry")
    func timelineBeginsWithAppliedEntry() async throws {
        let profileStore = try ProfileStore(container: ProfileStore.container(inMemory: true))
        try profileStore.load()
        try profileStore.createProfile(name: "Alex Climber", headline: "Staff Engineer")
        let role = try profileStore.addRole(
            company: "Acme", title: "Senior Engineer",
            start: Date(timeIntervalSince1970: 1_600_000_000), end: nil
        )
        try profileStore.addAchievement(to: role, text: "Cut CI build times across every product target")
        try profileStore.addAchievement(to: role, text: "Shipped the offline sync engine")
        try profileStore.addAchievement(to: role, text: "Led incident response for the payments outage")

        let tailorStore = TailorStore(
            profileStore: profileStore,
            keyStore: InMemoryAPIKeyStore(key: "sk-test"),
            makeIntelligence: { _ in FixtureIntelligenceService.tailorFixture() }
        )
        let details = JobDetails(
            company: "Summit Labs",
            roleTitle: "Platform Engineer",
            jobDescription: "Own platform reliability."
        )
        await tailorStore.startRun(details)
        let review = try #require(tailorStore.review)
        let exportStore = CVExportStore(container: profileStore.container)
        _ = try exportStore.export(
            profile: try #require(profileStore.profile), review: review, details: details)

        // load() backfills the applied date the timeline then reads.
        let pipelineStore = PipelineStore(container: profileStore.container)
        try pipelineStore.load()
        let application = try #require(pipelineStore.applications.first)

        let entries = TimelineModel.entries(for: application)
        let first = try #require(entries.first, "an applied Application has at least its applied entry")
        #expect(first.kind == .applied)
        #expect(first.label == "Applied")
        #expect(first.date == application.appliedAt)
        #expect(first.date != nil, "the applied entry is dated")
    }

    @Test("[TIMELINE-1] a draft Application has no applied entry")
    func draftHasNoAppliedEntry() throws {
        let application = Application(
            company: "Draft Co", roleTitle: "Engineer", jobDescription: "JD",
            status: .draft, appliedAt: nil,
            createdAt: Date(timeIntervalSince1970: 1_770_000_000)
        )
        let entries = TimelineModel.entries(for: application)
        #expect(!entries.contains { $0.kind == .applied })
    }

    // MARK: - Helpers

    private static let base = Date(timeIntervalSince1970: 1_770_000_000)
    private static func day(_ n: Double) -> Date { base.addingTimeInterval(n * 86_400) }

    /// An Application with Stages in an in-memory container; the context is
    /// returned so SwiftData keeps the relationship alive for the test.
    private func makeApplication(
        status: ApplicationStatus = .active,
        appliedAt: Date? = base,
        stages: [Stage] = []
    ) throws -> (ModelContext, Application) {
        let container = try ProfileStore.container(inMemory: true)
        let context = ModelContext(container)
        let application = Application(
            company: "Summit Labs", roleTitle: "Engineer", jobDescription: "JD",
            status: status, appliedAt: appliedAt, createdAt: Self.base
        )
        context.insert(application)
        application.stages = stages
        try context.save()
        return (context, application)
    }

    // MARK: - Heard back

    @Test("[TIMELINE-2] the heard-back entry carries the earliest date across the Application's Stages")
    func heardBackIsEarliestStageDate() throws {
        // Stage A's heardBackAt (day 8) beats its scheduledAt (day 10);
        // Stage B's scheduledAt (day 6) beats both — the minimum ranges over
        // both fields of every Stage.
        let (_, application) = try makeApplication(stages: [
            Stage(kind: .screen, scheduledAt: Self.day(10), heardBackAt: Self.day(8), sortIndex: 0),
            Stage(kind: .technical, scheduledAt: Self.day(6), sortIndex: 1),
        ])

        let entries = TimelineModel.entries(for: application)
        let heardBack = try #require(entries.first { $0.kind == .heardBack })
        #expect(heardBack.date == Self.day(6))
        #expect(heardBack.label == "Heard back")
        #expect(
            entries.firstIndex { $0.kind == .heardBack } == 1,
            "heard back sits between the applied entry and the Stage entries"
        )
    }

    @Test("[TIMELINE-3] an Application whose Stages carry no dates has no heard-back entry")
    func undatedStagesYieldNoHeardBack() throws {
        let (_, undated) = try makeApplication(stages: [
            Stage(kind: .screen, sortIndex: 0),
            Stage(kind: .technical, sortIndex: 1),
        ])
        #expect(!TimelineModel.entries(for: undated).contains { $0.kind == .heardBack })

        let (_, stageless) = try makeApplication(stages: [])
        #expect(!TimelineModel.entries(for: stageless).contains { $0.kind == .heardBack })
    }

    // MARK: - Entry order and outcome

    @Test("[TIMELINE-4] Stage entries follow the Stage chain's added order")
    func stageEntriesFollowSortIndex() throws {
        // Dates deliberately disagree with the chain order: the undated
        // technical Stage keeps its place, the late-scheduled screen stays first.
        let (_, application) = try makeApplication(stages: [
            Stage(kind: .screen, scheduledAt: Self.day(9), sortIndex: 0),
            Stage(kind: .technical, sortIndex: 1),
            Stage(kind: .final, scheduledAt: Self.day(2), sortIndex: 2),
        ])

        let stageKinds = TimelineModel.entries(for: application).compactMap { entry -> StageKind? in
            if case .stage(let kind) = entry.kind { return kind }
            return nil
        }
        #expect(stageKinds == [.screen, .technical, .final])
    }

    @Test(
        "[TIMELINE-5] a terminal Application's timeline ends with its outcome entry",
        arguments: [
            (ApplicationStatus.offer, "Offer"),
            (.rejected, "Rejected"),
            (.withdrawn, "Withdrawn"),
        ]
    )
    func terminalTimelineEndsWithOutcome(status: ApplicationStatus, label: String) throws {
        let (_, application) = try makeApplication(
            status: status,
            stages: [Stage(kind: .screen, scheduledAt: Self.day(3), sortIndex: 0)]
        )

        let entries = TimelineModel.entries(for: application)
        let last = try #require(entries.last)
        #expect(last.kind == .outcome(status))
        #expect(last.label == label)
    }

    @Test(
        "[TIMELINE-6] a non-terminal Application's timeline has no outcome entry",
        arguments: [ApplicationStatus.draft, .applied, .active]
    )
    func nonTerminalTimelineHasNoOutcome(status: ApplicationStatus) throws {
        let (_, application) = try makeApplication(
            status: status,
            stages: [Stage(kind: .screen, scheduledAt: Self.day(3), sortIndex: 0)]
        )

        let entries = TimelineModel.entries(for: application)
        #expect(!entries.contains { if case .outcome = $0.kind { return true } else { return false } })
    }

    // MARK: - Elapsed labels

    private func entry(_ kind: TimelineEntry.Kind, date: Date?) -> TimelineEntry {
        TimelineEntry(kind: kind, label: "", date: date, isFilled: true, blaze: .circle)
    }

    @Test("[TIMELINE-7] a segment between two dated entries is labeled with the whole days elapsed between them")
    func datedSegmentsCarrySpelledOutLabels() throws {
        let applied = entry(.applied, date: Self.day(0))
        #expect(
            TimelineModel.segmentLabel(from: applied, to: entry(.heardBack, date: Self.day(5)))
                == "5 days to hear back",
            "the applied → heard-back segment names the wait"
        )
        #expect(
            TimelineModel.segmentLabel(
                from: entry(.stage(.screen), date: Self.day(5)),
                to: entry(.stage(.technical), date: Self.day(8)))
                == "3 days"
        )
        #expect(
            TimelineModel.segmentLabel(
                from: entry(.stage(.screen), date: Self.day(5)),
                to: entry(.stage(.technical), date: Self.day(6)))
                == "1 day",
            "singular, never \"1 days\""
        )
        #expect(
            TimelineModel.segmentLabel(
                from: entry(.stage(.screen), date: Self.day(5)),
                to: entry(.stage(.technical), date: Self.day(5).addingTimeInterval(3_600)))
                == "same day"
        )
        // 09:00 → 08:00 five days later is 4 completed 24-hour days, not a
        // 5-calendar-date difference.
        #expect(
            TimelineModel.segmentLabel(
                from: entry(.applied, date: Self.day(0).addingTimeInterval(9 * 3_600)),
                to: entry(.heardBack, date: Self.day(5).addingTimeInterval(8 * 3_600)))
                == "4 days to hear back"
        )
    }

    @Test("[TIMELINE-8] a segment touching an undated entry carries no elapsed label")
    func undatedSegmentsCarryNoLabel() throws {
        let dated = entry(.stage(.screen), date: Self.day(5))
        let undated = entry(.stage(.technical), date: nil)
        #expect(TimelineModel.segmentLabel(from: dated, to: undated) == nil)
        #expect(TimelineModel.segmentLabel(from: undated, to: dated) == nil)
    }

    @Test("[TIMELINE-9] a non-terminal Application's in-stage label counts whole days since its latest dated entry")
    func inStageLabelCountsFromLatestDatedEntry() throws {
        // Latest dated entry is the technical Stage at day 6 — later than
        // the screen's day 3 and the applied day 0.
        let (_, application) = try makeApplication(stages: [
            Stage(kind: .screen, scheduledAt: Self.day(3), sortIndex: 0),
            Stage(kind: .technical, scheduledAt: Self.day(6), sortIndex: 1),
        ])

        #expect(TimelineModel.inStageLabel(for: application, asOf: Self.day(9)) == "In stage 3 days")
        #expect(TimelineModel.inStageLabel(for: application, asOf: Self.day(7)) == "In stage 1 day")
        #expect(
            TimelineModel.inStageLabel(
                for: application, asOf: Self.day(6).addingTimeInterval(3_600))
                == "In stage today",
            "under one whole day"
        )
    }

    @Test("[TIMELINE-9] the in-stage label is absent on terminal and undated Applications")
    func inStageLabelAbsentWhenTerminalOrUndated() throws {
        let (_, terminal) = try makeApplication(
            status: .rejected,
            stages: [Stage(kind: .screen, scheduledAt: Self.day(3), sortIndex: 0)]
        )
        #expect(TimelineModel.inStageLabel(for: terminal, asOf: Self.day(9)) == nil)

        let (_, undated) = try makeApplication(appliedAt: nil, stages: [
            Stage(kind: .screen, sortIndex: 0)
        ])
        #expect(TimelineModel.inStageLabel(for: undated, asOf: Self.day(9)) == nil)
    }

    // MARK: - Rendering derivations

    @Test("[TIMELINE-10] a Stage entry is filled exactly when its outcome is resolved")
    func stageEntriesFillWhenResolved() throws {
        let (_, application) = try makeApplication(stages: [
            Stage(kind: .screen, scheduledAt: Self.day(1), outcome: .passed, sortIndex: 0),
            Stage(kind: .technical, scheduledAt: Self.day(3), outcome: .failed, sortIndex: 1),
            Stage(kind: .behavioral, scheduledAt: Self.day(5), outcome: .noResponse, sortIndex: 2),
            Stage(kind: .final, scheduledAt: Self.day(7), outcome: .pending, sortIndex: 3),
        ])

        let entries = TimelineModel.entries(for: application)
        let stageFills = entries.compactMap { entry -> Bool? in
            if case .stage = entry.kind { return entry.isFilled }
            return nil
        }
        #expect(
            stageFills == [true, true, true, false],
            "passed, failed, and no-response fill; pending stays hollow"
        )
        #expect(
            entries.filter { $0.kind == .applied || $0.kind == .heardBack }
                .allSatisfy { $0.isFilled },
            "the applied and heard-back entries are always filled"
        )
    }

    @Test(
        "[TIMELINE-11] each stage kind renders its designated trail blaze",
        arguments: [
            (StageKind.screen, Blaze.circle),
            (.recruiter, .circle),
            (.technical, .diamond),
            (.systemDesign, .diamond),
            (.takeHome, .diamond),
            (.behavioral, .square),
            (.final, .doubleChevron),
            (.offer, .flag),
            (.other("Founder chat"), .circle),
        ]
    )
    func kindMapsToDesignatedBlaze(kind: StageKind, blaze: Blaze) throws {
        #expect(TimelineModel.blaze(for: kind) == blaze)
    }

    @Test("[TIMELINE-12] the content pane switches between the board and the selected Application's timeline")
    func contentPaneOffersBoardAndTimeline() throws {
        // Render-smoke only: toggle chrome and its no-selection disabling are
        // on the visual-verify list.
        let store = try PipelineStore(container: ProfileStore.container(inMemory: true))
        let context = ModelContext(store.container)
        let application = Application(
            company: "Summit Labs", roleTitle: "Engineer", jobDescription: "JD",
            status: .active, appliedAt: Self.base, createdAt: Self.base
        )
        context.insert(application)
        application.stages = [Stage(kind: .screen, scheduledAt: Self.day(3), sortIndex: 0)]
        try context.save()
        try store.load()

        let board = ImageRenderer(
            content: PipelineBoardView(store: store, selection: .constant(nil))
                .frame(width: 800, height: 500))
        #expect(board.nsImage != nil, "the board content root renders")
        let timeline = ImageRenderer(
            content: ApplicationTimelineView(application: application, asOf: Self.day(9))
                .frame(width: 800, height: 500))
        #expect(timeline.nsImage != nil, "the timeline content root renders")
    }
}

import Foundation
import SwiftData

enum PipelineStoreError: Error, Equatable {
    /// The move is outside the transition map (decisions/0003,
    /// [PIPEBOARD-6]).
    case illegalTransition(from: ApplicationStatus, to: ApplicationStatus)
}

/// MVVM-lite store for the pipeline board slice. All mutations save
/// immediately — persistence is part of the slice's promise, not a detail
/// (the ProfileStore convention).
@MainActor
@Observable
final class PipelineStore {
    /// Exposed like ProfileStore's — tests and sibling slices open their own
    /// contexts on the same store.
    let container: ModelContainer
    private let context: ModelContext
    private(set) var applications: [Application] = []

    init(container: ModelContainer) {
        self.container = container
        context = ModelContext(container)
    }

    /// Fetches every Application, newest-first by applied date falling back
    /// to creation date ([PIPEBOARD-4] ordering), after the backfill
    /// ([PIPEBOARD-8]): Phase 1 rows went straight to applied with no
    /// applied date — their export moment was their creation moment.
    /// Idempotent by construction: the predicate empties itself.
    func load() throws {
        let fetched = try context.fetch(FetchDescriptor<Application>())
        var backfilled = false
        for application in fetched where application.status == .applied && application.appliedAt == nil {
            application.appliedAt = application.createdAt
            backfilled = true
        }
        if backfilled {
            try context.save()
        }
        applications = fetched
            .sorted { ($0.appliedAt ?? $0.createdAt) > ($1.appliedAt ?? $1.createdAt) }
    }

    /// One column's applications ([PIPEBOARD-4]): every Application whose
    /// status matches, keeping `load()`'s newest-first order.
    func applications(in status: ApplicationStatus) -> [Application] {
        applications.filter { $0.status == status }
    }

    /// The transition map (decisions/0003): rejected and withdrawn are
    /// terminal — closed trails stay closed.
    static let legalTransitions: [ApplicationStatus: Set<ApplicationStatus>] = [
        .draft: [.applied, .withdrawn],
        .applied: [.active, .rejected, .withdrawn],
        .active: [.offer, .rejected, .withdrawn],
        .offer: [.withdrawn],
        .rejected: [],
        .withdrawn: [],
    ]

    /// Whether the board may offer this drop target ([PIPEBOARD-6]: the
    /// board only offers legal targets; the store's throw is the guarantee).
    static func canMove(from: ApplicationStatus, to: ApplicationStatus) -> Bool {
        from == to || legalTransitions[from, default: []].contains(to)
    }

    /// Moves an Application along the transition map ([PIPEBOARD-5]). A
    /// same-status drop is a no-op; an illegal move throws and changes
    /// nothing ([PIPEBOARD-6]).
    func move(_ application: Application, to status: ApplicationStatus) throws {
        guard application.status != status else { return }
        guard Self.canMove(from: application.status, to: status) else {
            throw PipelineStoreError.illegalTransition(from: application.status, to: status)
        }
        application.status = status
        // Applying is the moment the date records ([PIPEBOARD-9]); an
        // existing date is never overwritten.
        if status == .applied && application.appliedAt == nil {
            application.appliedAt = .now
        }
        try context.save()
    }

    /// Appends a Stage to the Application's chain ([PIPEBOARD-1]);
    /// `sortIndex` continues the chain (the [PROFILE-7] pattern). The one
    /// auto-advance (decisions/0003, [PIPEBOARD-7]): a first Stage on an
    /// applied Application sets it active.
    @discardableResult
    func addStage(
        to application: Application,
        kind: StageKind,
        scheduledAt: Date? = nil,
        meetingURL: URL? = nil,
        prepContext: String = ""
    ) throws -> Stage {
        let stage = Stage(
            kind: kind,
            scheduledAt: scheduledAt,
            meetingURL: meetingURL,
            prepContext: prepContext,
            sortIndex: (application.stages.map(\.sortIndex).max() ?? -1) + 1
        )
        let isFirstStage = application.stages.isEmpty
        context.insert(stage)
        stage.application = application
        if isFirstStage && application.status == .applied {
            application.status = .active
        }
        try context.save()
        return stage
    }

    /// The application detail's edits ([PIPEBOARD-12]): source, notes, and
    /// an explicit applied-date correction.
    func updateDetails(
        _ application: Application,
        source: String?,
        notes: String,
        appliedAt: Date?
    ) throws {
        application.source = source
        application.notes = notes
        application.appliedAt = appliedAt
        try context.save()
    }

    /// Resolves a board drop's payload back to the store's own instance.
    func application(for id: PersistentIdentifier) -> Application? {
        context.model(for: id) as? Application
    }

    /// The card's next waypoint ([PIPEBOARD-13]): the earliest pending Stage
    /// in chain order, nil when none — pure so the derivation tests without
    /// views. "Next waypoint" is footer narrative (slice CONTEXT.md).
    static func nextWaypoint(for application: Application) -> StageKind? {
        application.orderedStages.first { $0.outcome == .pending }?.kind
    }

    /// The Stage form's edits ([PIPEBOARD-15]): every editable field in one
    /// save. `calendarEventID` is calendar-sync's to write, not the form's.
    func updateStage(
        _ stage: Stage,
        kind: StageKind,
        scheduledAt: Date?,
        outcome: StageOutcome,
        heardBackAt: Date?,
        prepContext: String,
        meetingURL: URL?
    ) throws {
        stage.kind = kind
        stage.scheduledAt = scheduledAt
        stage.outcome = outcome
        stage.heardBackAt = heardBackAt
        stage.prepContext = prepContext
        stage.meetingURL = meetingURL
        try context.save()
    }

    /// The card's elapsed-time footer ([PIPEBOARD-16]): whole days from the
    /// applied date (falling back to creation) to `asOf` — the parameter
    /// keeps tests deterministic. "Days on trail" is footer narrative
    /// (slice CONTEXT.md).
    static func daysOnTrail(for application: Application, asOf: Date) -> Int {
        let start = application.appliedAt ?? application.createdAt
        return max(0, Int(asOf.timeIntervalSince(start) / 86_400))
    }

    /// Removes one Stage from its chain ([PIPEBOARD-11]).
    func deleteStage(_ stage: Stage) throws {
        context.delete(stage)
        try context.save()
    }

    /// Removes an Application; the cascade rule takes its Stages with it
    /// ([PIPEBOARD-11]).
    func deleteApplication(_ application: Application) throws {
        context.delete(application)
        try context.save()
        applications.removeAll { $0.persistentModelID == application.persistentModelID }
    }
}

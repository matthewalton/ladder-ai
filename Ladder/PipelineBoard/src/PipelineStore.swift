import Foundation
import SwiftData

enum PipelineStoreError: Error, Equatable {
    case illegalTransition(from: ApplicationStatus, to: ApplicationStatus)
    case blankField
}

/// Every mutation saves immediately.
@MainActor
@Observable
final class PipelineStore {
    /// Exposed so tests and sibling slices can open their own contexts on the same store.
    let container: ModelContainer
    private let context: ModelContext
    private(set) var applications: [Application] = []

    init(container: ModelContainer) {
        self.container = container
        context = ModelContext(container)
    }

    /// Backfills applied dates for Phase 1 rows, which went straight to
    /// applied with none recorded — their export moment was their creation moment.
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

    func applications(in status: ApplicationStatus) -> [Application] {
        applications.filter { $0.status == status }
    }

    /// Creates without CV fields — export stays the only path that attaches
    /// one. Duplicate company/role pairs are allowed by design.
    @discardableResult
    func createApplication(
        company: String, roleTitle: String,
        source: String?, notes: String,
        appliedAt: Date?
    ) throws -> Application {
        guard !company.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !roleTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw PipelineStoreError.blankField
        }
        let application = Application(
            company: company, roleTitle: roleTitle, jobDescription: "",
            status: appliedAt == nil ? .draft : .applied,
            source: source, appliedAt: appliedAt, notes: notes
        )
        context.insert(application)
        try context.save()
        try load()
        return application
    }

    static let legalTransitions: [ApplicationStatus: Set<ApplicationStatus>] = [
        .draft: [.applied, .withdrawn],
        .applied: [.active, .rejected, .withdrawn],
        .active: [.offer, .rejected, .withdrawn],
        .offer: [.withdrawn],
        .rejected: [],
        .withdrawn: [],
    ]

    /// UI gating only — `move`'s throw is the real guarantee.
    static func canMove(from: ApplicationStatus, to: ApplicationStatus) -> Bool {
        from == to || legalTransitions[from, default: []].contains(to)
    }

    func move(_ application: Application, to status: ApplicationStatus) throws {
        guard application.status != status else { return }
        guard Self.canMove(from: application.status, to: status) else {
            throw PipelineStoreError.illegalTransition(from: application.status, to: status)
        }
        application.status = status
        if status == .applied && application.appliedAt == nil {
            application.appliedAt = .now
        }
        try context.save()
    }

    /// The store's only auto-advance: a first Stage on an applied
    /// Application sets it active.
    @discardableResult
    func addStage(
        to application: Application,
        kind: StageKind,
        scheduledAt: Date? = nil,
        calendarEventID: String? = nil,
        meetingURL: URL? = nil,
        prepContext: String = ""
    ) throws -> Stage {
        let stage = Stage(
            kind: kind,
            scheduledAt: scheduledAt,
            calendarEventID: calendarEventID,
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

    func application(for id: PersistentIdentifier) -> Application? {
        context.model(for: id) as? Application
    }

    static func nextWaypoint(for application: Application) -> StageKind? {
        application.orderedStages.first { $0.outcome == .pending }?.kind
    }

    /// `calendarEventID` is calendar-sync's to write — deliberately not editable here.
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

    static func daysOnTrail(for application: Application, asOf: Date) -> Int {
        let start = application.appliedAt ?? application.createdAt
        return max(0, Int(asOf.timeIntervalSince(start) / 86_400))
    }

    func deleteStage(_ stage: Stage) throws {
        context.delete(stage)
        try context.save()
    }

    func deleteApplication(_ application: Application) throws {
        context.delete(application)
        try context.save()
        applications.removeAll { $0.persistentModelID == application.persistentModelID }
    }
}

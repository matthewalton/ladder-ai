import Foundation
import SwiftData

enum CalendarScanState: Equatable, Sendable {
    case idle
    case scanning
    case ready
    case denied
}

struct StageProposal: Identifiable {
    let event: CalendarEvent
    /// Tracked Applications the event could attach to, in board order.
    let candidates: [Application]
    let meetingLink: URL?
    let kindGuess: StageKind?
    var companyGuess: String?

    var id: String { event.identifier }

    var isPossibleInterview: Bool { candidates.isEmpty }
}

/// Scan, match, propose — confirmation is the only write path.
@MainActor
@Observable
final class CalendarSyncStore {
    private let pipeline: PipelineStore
    private let service: any CalendarSyncService
    private let context: ModelContext
    /// nonisolated(unsafe): only written from MainActor, read once in deinit.
    @ObservationIgnored nonisolated(unsafe) private var changeObserver: (any NSObjectProtocol)?

    private(set) var scanState: CalendarScanState = .idle
    private(set) var proposals: [StageProposal] = []
    /// Fetched by the most recent check — an automatic scan never fills
    /// this, and it is never persisted (decisions/0008).
    private var checkedEvents: [CalendarEvent] = []

    /// The check's fetched events that produced no proposal — linked,
    /// dismissed, and proposed events excluded, in start order. Computed
    /// live so a confirmation or dismissal mid-review drops out.
    var otherEvents: [CalendarEvent] {
        let linked = linkedEventIDs()
        let dismissed = dismissedEventIDs()
        let proposed = Set(proposals.map(\.id))
        return checkedEvents
            .filter {
                !linked.contains($0.identifier)
                    && !dismissed.contains($0.identifier)
                    && !proposed.contains($0.identifier)
            }
            .sorted { $0.start < $1.start }
    }

    /// A proposal on demand for a picked other event — the interview
    /// heuristic's verdict is ignored here.
    func proposal(for event: CalendarEvent) -> StageProposal {
        makeProposal(
            for: event,
            candidates: trackedApplications().filter {
                CalendarMatcher.matches(event: event, company: $0.company)
            }
        )
    }

    /// The look-back is on demand only — never automatic, never the
    /// standing scan window.
    static func lookBackWindow(asOf: Date) -> DateInterval {
        DateInterval(start: asOf.addingTimeInterval(-90 * 86_400), end: asOf)
    }

    func lookBack(for application: Application, asOf: Date = .now) async {
        scanState = .scanning
        var access = await service.accessState()
        if access == .notDetermined {
            access = await service.requestAccess()
        }
        guard access == .granted else {
            scanState = .denied
            return
        }

        do {
            let events = try await service.events(in: Self.lookBackWindow(asOf: asOf))
            let linked = linkedEventIDs()
            let dismissed = dismissedEventIDs()
            let proposed = Set(proposals.map(\.id))
            let found = events
                .filter { event in
                    !linked.contains(event.identifier)
                        && !dismissed.contains(event.identifier)
                        && !proposed.contains(event.identifier)
                        && CalendarMatcher.matches(event: event, company: application.company)
                }
                .map { makeProposal(for: $0, candidates: [application]) }
            proposals = (proposals + found).sorted { $0.event.start < $1.event.start }
        } catch {
            // A failed look-back leaves the standing proposals alone.
        }
        scanState = .ready
    }

    init(pipeline: PipelineStore, service: any CalendarSyncService) {
        self.pipeline = pipeline
        self.service = service
        self.context = ModelContext(pipeline.container)
    }

    deinit {
        if let changeObserver {
            NotificationCenter.default.removeObserver(changeObserver)
        }
    }

    /// Seven days back keeps a just-happened interview linkable; thirty
    /// ahead covers any scheduled round.
    static func scanWindow(asOf: Date) -> DateInterval {
        DateInterval(
            start: asOf.addingTimeInterval(-7 * 86_400),
            end: asOf.addingTimeInterval(30 * 86_400)
        )
    }

    /// The automatic form — launch and the calendar-change signal.
    /// Refreshes proposals and populates no other events (decisions/0008).
    func scan(asOf: Date = .now) async {
        checkedEvents = []
        await performScan(asOf: asOf)
    }

    /// The user-initiated form — "Check calendar". The one scan that keeps
    /// its unproposed events as other events (decisions/0008), and also the
    /// explicit gesture that first requests calendar access.
    func check(asOf: Date = .now) async {
        checkedEvents = await performScan(asOf: asOf)
    }

    /// Closing the check-results sheet ends the review; the other events
    /// only come back with the next check (decisions/0008).
    func discardOtherEvents() {
        checkedEvents = []
    }

    /// The access prompt is never unprompted: this only runs from an
    /// explicit user action or an already-granted launch.
    @discardableResult
    private func performScan(asOf: Date) async -> [CalendarEvent] {
        scanState = .scanning
        var access = await service.accessState()
        if access == .notDetermined {
            access = await service.requestAccess()
        }
        guard access == .granted else {
            proposals = []
            scanState = .denied
            return []
        }

        do {
            let events = try await service.events(in: Self.scanWindow(asOf: asOf))
            proposals = buildProposals(from: events)
            scanState = .ready
            return events
        } catch {
            proposals = []
            scanState = .ready
            return []
        }
    }

    /// Subscription is synchronous so a signal posted right after this call
    /// is never missed; the scan itself hops to the main actor.
    func startObservingChanges(center: NotificationCenter = .default) {
        guard changeObserver == nil else { return }
        changeObserver = center.addObserver(
            forName: .calendarSyncDidChange, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.scan()
            }
        }
    }

    @discardableResult
    func confirm(
        _ proposal: StageProposal, application: Application, kind: StageKind
    ) throws -> Stage {
        let stage = try pipeline.addStage(
            to: application,
            kind: kind,
            scheduledAt: proposal.event.start,
            calendarEventID: proposal.event.identifier,
            meetingURL: proposal.meetingLink
        )
        proposals.removeAll { $0.id == proposal.id }
        return stage
    }

    /// Goes through the pipeline's own creation paths so its invariants —
    /// blank fields refuse, the first Stage auto-advances — both hold.
    @discardableResult
    func confirmCreate(
        _ proposal: StageProposal, company: String, roleTitle: String, kind: StageKind
    ) throws -> Stage {
        // Applied at the event's start — the best evidence on hand.
        let application = try pipeline.createApplication(
            company: company, roleTitle: roleTitle,
            source: "calendar", notes: "",
            appliedAt: proposal.event.start
        )
        let stage = try pipeline.addStage(
            to: application,
            kind: kind,
            scheduledAt: proposal.event.start,
            calendarEventID: proposal.event.identifier,
            meetingURL: proposal.meetingLink
        )
        proposals.removeAll { $0.id == proposal.id }
        return stage
    }

    /// Writes calendar fields only — kind and outcome stay untouched.
    func link(_ proposal: StageProposal, to stage: Stage) throws {
        guard let local = context.model(for: stage.persistentModelID) as? Stage else {
            return
        }
        local.calendarEventID = proposal.event.identifier
        local.meetingURL = proposal.meetingLink
        local.scheduledAt = proposal.event.start
        try context.save()
        proposals.removeAll { $0.id == proposal.id }
    }

    func dismiss(_ proposal: StageProposal, asOf: Date = .now) throws {
        context.insert(
            DismissedEvent(calendarEventID: proposal.event.identifier, dismissedAt: asOf)
        )
        try context.save()
        proposals.removeAll { $0.id == proposal.id }
    }

    /// Draft is not yet sent; rejected and withdrawn are closed.
    static let trackedStatuses: Set<ApplicationStatus> = [.applied, .active, .offer]

    /// Computed live, not captured at scan time, so the empty-scan explainer
    /// stays truthful when the board changes after a scan.
    var hasTrackedApplications: Bool {
        pipeline.applications.contains { Self.trackedStatuses.contains($0.status) }
    }

    private func trackedApplications() -> [Application] {
        pipeline.applications.filter { Self.trackedStatuses.contains($0.status) }
    }

    private func makeProposal(
        for event: CalendarEvent, candidates: [Application]
    ) -> StageProposal {
        StageProposal(
            event: event,
            candidates: candidates,
            meetingLink: MeetingLinkDetector.meetingLink(in: event),
            kindGuess: StageKindGuesser.guess(fromTitle: event.title),
            companyGuess: candidates.isEmpty ? CompanyGuesser.guess(for: event) : nil
        )
    }

    private func buildProposals(from events: [CalendarEvent]) -> [StageProposal] {
        let tracked = trackedApplications()
        let linked = linkedEventIDs()
        let dismissed = dismissedEventIDs()
        return events
            .sorted { $0.start < $1.start }
            .compactMap { event in
                guard !linked.contains(event.identifier),
                    !dismissed.contains(event.identifier)
                else { return nil }
                let candidates = tracked.filter {
                    CalendarMatcher.matches(event: event, company: $0.company)
                }
                // Matching wins; the heuristic only sees the leftovers.
                if candidates.isEmpty {
                    guard InterviewHeuristic.flags(event) else { return nil }
                }
                return makeProposal(for: event, candidates: candidates)
            }
    }

    private func linkedEventIDs() -> Set<String> {
        let stages = (try? context.fetch(FetchDescriptor<Stage>())) ?? []
        return Set(stages.compactMap(\.calendarEventID))
    }

    private func dismissedEventIDs() -> Set<String> {
        let records = (try? context.fetch(FetchDescriptor<DismissedEvent>())) ?? []
        return Set(records.map(\.calendarEventID))
    }
}

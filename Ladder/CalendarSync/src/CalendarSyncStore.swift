import Foundation
import SwiftData

/// Where a scan stands (slice CONTEXT.md: denied state). Denied is a state,
/// not an error — the rest of the app never depends on a scan having run
/// ([CALSYNC-17]).
enum CalendarScanState: Equatable, Sendable {
    case idle
    case scanning
    case ready
    case denied
}

/// One scanned event proposed to the user (slice CONTEXT.md: proposal).
/// Store state only — never persisted; only confirmation writes
/// ([CALSYNC-2]).
struct StageProposal: Identifiable {
    let event: CalendarEvent
    /// Tracked Applications the event could attach to, in board order
    /// ([CALSYNC-6]). Empty means a possible-interview proposal
    /// (decisions/0007): the event matched nothing, and confirmation
    /// creates ([CALSYNC-26]) instead of attaching.
    let candidates: [Application]
    let meetingLink: URL?
    let kindGuess: StageKind?
    /// The sheet's company pre-fill ([CALSYNC-24], [CALSYNC-25]) — carried
    /// only on possible-interview proposals.
    var companyGuess: String?

    var id: String { event.identifier }

    var isPossibleInterview: Bool { candidates.isEmpty }
}

/// MVVM-lite store for the calendar-sync slice: scan, match, propose —
/// confirmation is the only write path (ARCHITECTURE.md §6, [CALSYNC-2]).
/// Matching runs against the PipelineStore's loaded Applications; Stage
/// creation goes through `PipelineStore.addStage` so the [PIPEBOARD-7]
/// auto-advance holds ([CALSYNC-8]).
@MainActor
@Observable
final class CalendarSyncStore {
    private let pipeline: PipelineStore
    private let service: any CalendarSyncService
    private let context: ModelContext
    /// nonisolated(unsafe): only written from MainActor, read once in deinit
    /// after all other references are gone.
    @ObservationIgnored nonisolated(unsafe) private var changeObserver: (any NSObjectProtocol)?

    private(set) var scanState: CalendarScanState = .idle
    private(set) var proposals: [StageProposal] = []
    /// Everything the last scan fetched, before matching and the heuristic —
    /// the raw material of the browse list ([CALSYNC-27]).
    private var fetchedEvents: [CalendarEvent] = []

    /// The browse list ([CALSYNC-27]): every fetched window event minus
    /// linked and dismissed ones, in start order. Computed live, so a
    /// confirmation or dismissal drops the event without a re-scan.
    var browseEvents: [CalendarEvent] {
        let linked = linkedEventIDs()
        let dismissed = dismissedEventIDs()
        return fetchedEvents
            .filter { !linked.contains($0.identifier) && !dismissed.contains($0.identifier) }
            .sorted { $0.start < $1.start }
    }

    /// Picking a browsed event ([CALSYNC-28]): a proposal on demand, the
    /// heuristic's verdict ignored — candidates when matching finds tracked
    /// Applications, possible-interview when it does not.
    func proposal(for event: CalendarEvent) -> StageProposal {
        makeProposal(
            for: event,
            candidates: trackedApplications().filter {
                CalendarMatcher.matches(event: event, company: $0.company)
            }
        )
    }

    /// The on-demand look-back scan ([CALSYNC-29], [CALSYNC-30]): ninety
    /// days back to the scan instant, matched against one application's
    /// company only — never automatic, never the standing window
    /// (decisions/0007).
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
                // The sole candidate is the application the action was
                // invoked on ([CALSYNC-30]) — confirmation lands there.
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

    /// The scan window (decisions/0003): seven days back keeps a
    /// just-happened interview linkable, thirty ahead covers any scheduled
    /// round. `asOf` keeps tests deterministic ([CALSYNC-13]).
    static func scanWindow(asOf: Date) -> DateInterval {
        DateInterval(
            start: asOf.addingTimeInterval(-7 * 86_400),
            end: asOf.addingTimeInterval(30 * 86_400)
        )
    }

    /// One pass over the window (slice CONTEXT.md: scan). Requests access
    /// when not yet determined — scan only ever runs from an explicit user
    /// action or an already-granted launch (decisions/0001).
    func scan(asOf: Date = .now) async {
        scanState = .scanning
        var access = await service.accessState()
        if access == .notDetermined {
            access = await service.requestAccess()
        }
        guard access == .granted else {
            proposals = []
            scanState = .denied
            return
        }

        do {
            let events = try await service.events(in: Self.scanWindow(asOf: asOf))
            fetchedEvents = events
            proposals = buildProposals(from: events)
        } catch {
            fetchedEvents = []
            proposals = []
        }
        scanState = .ready
    }

    /// Re-scan on the seam's change signal (decisions/0003, [CALSYNC-14]).
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

    /// Turning a proposal into a new pending Stage (slice CONTEXT.md:
    /// confirmation, [CALSYNC-8]) — through `PipelineStore.addStage` so the
    /// [PIPEBOARD-7] auto-advance holds.
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

    /// The calendar-first write path ([CALSYNC-26], decisions/0007): one
    /// confirmation creates the applied Application and its event-linked
    /// Stage — through the pipeline's own creation paths, so the manual
    /// add's invariants (blank fields refuse) and the [PIPEBOARD-7]
    /// auto-advance both hold.
    @discardableResult
    func confirmCreate(
        _ proposal: StageProposal, company: String, roleTitle: String, kind: StageKind
    ) throws -> Stage {
        // Applied at the event's start — the best evidence on hand
        // (decisions/0007); createApplication refuses blanks before
        // anything is created.
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

    /// The link path ([CALSYNC-9]): the event onto a Stage the user already
    /// tracks — calendar fields only, kind and outcome untouched, nothing
    /// created.
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

    /// Declining a proposal (slice CONTEXT.md: dismissal, [CALSYNC-11]):
    /// persisted by event identifier so it never comes back
    /// (decisions/0004).
    func dismiss(_ proposal: StageProposal, asOf: Date = .now) throws {
        context.insert(
            DismissedEvent(calendarEventID: proposal.event.identifier, dismissedAt: asOf)
        )
        try context.save()
        proposals.removeAll { $0.id == proposal.id }
    }

    /// Statuses a calendar event can match (decisions/0002): draft is not
    /// yet sent; rejected and withdrawn are closed.
    static let trackedStatuses: Set<ApplicationStatus> = [.applied, .active, .offer]

    /// Which empty-scan explainer applies ([CALSYNC-19], [CALSYNC-20]):
    /// computed live rather than captured at scan time, so the explainer
    /// stays truthful when the board changes after a scan (decisions/0006).
    var hasTrackedApplications: Bool {
        pipeline.applications.contains { Self.trackedStatuses.contains($0.status) }
    }

    private func trackedApplications() -> [Application] {
        pipeline.applications.filter { Self.trackedStatuses.contains($0.status) }
    }

    /// One proposal, whatever surfaced the event: candidates when matched,
    /// possible-interview (company guess carried) when not.
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
                // Matching wins; the interview heuristic only looks at the
                // leftovers — an empty board included (decisions/0007,
                // [CALSYNC-21]–[CALSYNC-23]).
                if candidates.isEmpty {
                    guard InterviewHeuristic.flags(event) else { return nil }
                }
                return makeProposal(for: event, candidates: candidates)
            }
    }

    /// Events some Stage already carries ([CALSYNC-10]) — suppressed the
    /// same way dismissals are.
    private func linkedEventIDs() -> Set<String> {
        let stages = (try? context.fetch(FetchDescriptor<Stage>())) ?? []
        return Set(stages.compactMap(\.calendarEventID))
    }

    private func dismissedEventIDs() -> Set<String> {
        let records = (try? context.fetch(FetchDescriptor<DismissedEvent>())) ?? []
        return Set(records.map(\.calendarEventID))
    }
}

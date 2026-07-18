import Foundation

/// In-code canned events for tests and previews (decisions/0001) — the
/// `FixtureIntelligenceService` pattern: no EventKit, no permission, and it
/// records every interval it is asked for ([CALSYNC-13]).
actor FixtureCalendarSyncService: CalendarSyncService {
    private var state: CalendarAccessState
    private var fixtureEvents: [CalendarEvent]
    private let accessRequestResult: CalendarAccessState
    private(set) var requestedIntervals: [DateInterval] = []

    init(
        events: [CalendarEvent] = [],
        state: CalendarAccessState = .granted,
        accessRequestResult: CalendarAccessState = .granted
    ) {
        self.fixtureEvents = events
        self.state = state
        self.accessRequestResult = accessRequestResult
    }

    func accessState() async -> CalendarAccessState { state }

    func requestAccess() async -> CalendarAccessState {
        if state == .notDetermined {
            state = accessRequestResult
        }
        return state
    }

    func events(in interval: DateInterval) async throws -> [CalendarEvent] {
        requestedIntervals.append(interval)
        return fixtureEvents.filter { interval.contains($0.start) }
    }
}

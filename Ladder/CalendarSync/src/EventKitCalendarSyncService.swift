import EventKit
import Foundation

/// Read-only EventKit access, exercised by humans only — no test constructs
/// an EKEventStore.
final class EventKitCalendarSyncService: CalendarSyncService, @unchecked Sendable {
    // @unchecked: EKEventStore is documented thread-safe; the observer token
    // is written once in init and read once in deinit.
    private let store = EKEventStore()
    private var observer: (any NSObjectProtocol)?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: nil
        ) { _ in
            NotificationCenter.default.post(name: .calendarSyncDidChange, object: nil)
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func accessState() async -> CalendarAccessState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .granted
        case .notDetermined: .notDetermined
        // Write-only access cannot read events, so it counts as denied.
        default: .denied
        }
    }

    func requestAccess() async -> CalendarAccessState {
        let granted = (try? await store.requestFullAccessToEvents()) ?? false
        return granted ? .granted : .denied
    }

    func events(in interval: DateInterval) async throws -> [CalendarEvent] {
        let predicate = store.predicateForEvents(
            withStart: interval.start, end: interval.end, calendars: nil
        )
        return store.events(matching: predicate).map { event in
            CalendarEvent(
                identifier: event.eventIdentifier ?? UUID().uuidString,
                title: event.title ?? "",
                start: event.startDate,
                end: event.endDate,
                location: event.location,
                notes: event.notes,
                attendeeEmails: (event.attendees ?? []).compactMap(Self.email(of:)),
                organizerName: event.organizer?.name,
                organizerEmail: event.organizer.flatMap(Self.email(of:))
            )
        }
    }

    private static func email(of participant: EKParticipant) -> String? {
        let url = participant.url.absoluteString
        guard url.lowercased().hasPrefix("mailto:") else { return nil }
        return String(url.dropFirst("mailto:".count))
    }
}

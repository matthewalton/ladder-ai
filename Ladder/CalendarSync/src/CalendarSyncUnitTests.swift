import Foundation
import Testing

@testable import Ladder

struct CalendarSyncUnitTests {
    @Test("[CALSYNC-5] matching ignores case and punctuation in the company name")
    func normalisedCompanyMatching() {
        // Corporate suffixes fall away too.
        #expect(CalendarMatcher.contains("ACME interview", company: "Acme, Corp."))
        #expect(CalendarMatcher.contains("Interview with acme corp", company: "ACME"))
        #expect(CalendarMatcher.contains("Round 2 — Wayne Enterprises Ltd.", company: "wayne enterprises"))
        // Whole-word containment: "Acme" never matches "Acmex".
        #expect(!CalendarMatcher.contains("Acmex interview", company: "Acme"))
        #expect(!CalendarMatcher.contains("Interview", company: "Acme"))
    }

    @Test("[CALSYNC-34] the other-events filter narrows the list to events whose title contains the typed text")
    func filterNarrowsOtherEventsByTitle() {
        let start = Date(timeIntervalSince1970: 1_752_800_000)
        let events = [
            CalendarEvent(identifier: "evt-1", title: "Interview with Hooli", start: start),
            CalendarEvent(identifier: "evt-2", title: "Team standup", start: start),
            CalendarEvent(identifier: "evt-3", title: "HOOLI follow-up", start: start),
        ]
        // Containment ignores case.
        #expect(
            OtherEventsFilter.filtered(events, titleContains: "hooli").map(\.identifier)
                == ["evt-1", "evt-3"]
        )
        // An empty or blank filter shows the whole list.
        #expect(OtherEventsFilter.filtered(events, titleContains: "").count == 3)
        #expect(OtherEventsFilter.filtered(events, titleContains: "   ").count == 3)
        // No match → nothing.
        #expect(OtherEventsFilter.filtered(events, titleContains: "dentist").isEmpty)
    }

    @Test("[CALSYNC-18] the app bundle carries the calendar full-access usage description")
    func usageDescriptionIsPresent() {
        // Tests run in the app host, so Bundle.main is Ladder.app — the same
        // Info dictionary the permission prompt reads.
        let copy = Bundle.main.object(
            forInfoDictionaryKey: "NSCalendarsFullAccessUsageDescription"
        ) as? String
        #expect(copy?.isEmpty == false)
    }
}

import Foundation
import Testing

@testable import Ladder

/// Pure-helper criteria: the matcher's normalisation and the kind guess —
/// no container, no service.
struct CalendarSyncUnitTests {
    @Test("[CALSYNC-5] matching ignores case and punctuation in the company name")
    func normalisedCompanyMatching() {
        // Case, punctuation, and corporate suffixes all fall away
        // (decisions/0002).
        #expect(CalendarMatcher.contains("ACME interview", company: "Acme, Corp."))
        #expect(CalendarMatcher.contains("Interview with acme corp", company: "ACME"))
        #expect(CalendarMatcher.contains("Round 2 — Wayne Enterprises Ltd.", company: "wayne enterprises"))
        // Whole-word containment: "Acme" never matches "Acmex".
        #expect(!CalendarMatcher.contains("Acmex interview", company: "Acme"))
        #expect(!CalendarMatcher.contains("Interview", company: "Acme"))
    }

    @Test("[CALSYNC-18] the app bundle carries the calendar full-access usage description")
    func usageDescriptionIsPresent() {
        // Tests run in the app host, so Bundle.main is Ladder.app — the same
        // Info dictionary the permission prompt reads (decisions/0001).
        let copy = Bundle.main.object(
            forInfoDictionaryKey: "NSCalendarsFullAccessUsageDescription"
        ) as? String
        #expect(copy?.isEmpty == false)
    }
}

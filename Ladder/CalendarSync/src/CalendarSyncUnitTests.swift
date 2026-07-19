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

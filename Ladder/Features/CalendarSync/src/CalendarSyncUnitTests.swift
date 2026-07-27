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

    @Test("[CALSYNC-35] the calendar section derives one sidebar row per pending proposal")
    func calendarSectionRowsMirrorProposals() {
        let start = Date(timeIntervalSince1970: 1_752_800_000)
        let acme = Application(
            company: "Acme", roleTitle: "Engineer", jobDescription: "JD",
            status: .applied, appliedAt: start
        )
        let matched = StageProposal(
            event: CalendarEvent(identifier: "evt-1", title: "Acme phone screen", start: start),
            candidates: [acme], meetingLink: nil, kindGuess: .screen, companyGuess: nil
        )
        let possible = StageProposal(
            event: CalendarEvent(
                identifier: "evt-2", title: "Interview with Hooli",
                start: start.addingTimeInterval(3_600)
            ),
            candidates: [], meetingLink: nil, kindGuess: nil, companyGuess: "Hooli"
        )

        let rows = CalendarSection.rows(from: [matched, possible])
        // One row per proposal, in scan order.
        #expect(rows.map(\.id) == ["evt-1", "evt-2"])
        #expect(rows[0].title == "Acme phone screen")
        #expect(rows[0].start == start)
        #expect(rows[0].kindGuess == .screen)
        #expect(!rows[0].isPossibleInterview)
        #expect(rows[1].isPossibleInterview)
        #expect(rows[1].kindGuess == nil)
        // Zero proposals → no section at all; the divider never renders alone.
        #expect(CalendarSection.rows(from: []).isEmpty)
    }

    @Test("[CALSYNC-36] the bar renders only its header row and the explainers")
    func barContentNeverListsProposals() {
        // Proposals pending, no explainer state → the header row alone;
        // the content type has no proposals case to render.
        #expect(
            CalendarBarContent.content(
                scanState: .ready, hasProposals: true, hasTrackedApplications: true
            ) == .headerOnly
        )
        // The explainers keep their [CALSYNC-17]/[CALSYNC-19]/[CALSYNC-20] signals.
        #expect(
            CalendarBarContent.content(
                scanState: .denied, hasProposals: false, hasTrackedApplications: true
            ) == .deniedExplainer
        )
        #expect(
            CalendarBarContent.content(
                scanState: .ready, hasProposals: false, hasTrackedApplications: false
            ) == .noTrackedExplainer
        )
        #expect(
            CalendarBarContent.content(
                scanState: .ready, hasProposals: false, hasTrackedApplications: true
            ) == .noMatchesExplainer
        )
        // No explainer while idle or scanning.
        #expect(
            CalendarBarContent.content(
                scanState: .idle, hasProposals: false, hasTrackedApplications: true
            ) == .headerOnly
        )
        #expect(
            CalendarBarContent.content(
                scanState: .scanning, hasProposals: false, hasTrackedApplications: false
            ) == .headerOnly
        )
    }
}

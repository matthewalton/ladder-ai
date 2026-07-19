import Foundation
import SwiftData
import Testing

@testable import Ladder

/// Scan → match → propose → confirm criteria, all through the fixture
/// service (decisions/0001): no EventKit, no calendar permission.
@MainActor
struct CalendarSyncFlowTests {
    /// A fixed instant keeps every window computation deterministic.
    static let now = Date(timeIntervalSince1970: 1_752_800_000)

    private func makeStores(
        events: [CalendarEvent],
        state: CalendarAccessState = .granted,
        accessRequestResult: CalendarAccessState = .granted
    ) throws -> (pipeline: PipelineStore, sync: CalendarSyncStore, service: FixtureCalendarSyncService) {
        let container = try ProfileStore.container(inMemory: true)
        let pipeline = PipelineStore(container: container)
        let service = FixtureCalendarSyncService(
            events: events, state: state, accessRequestResult: accessRequestResult
        )
        let sync = CalendarSyncStore(pipeline: pipeline, service: service)
        return (pipeline, sync, service)
    }

    /// Seeds an Application the way cv-export creates them and reloads the
    /// pipeline so matching sees it.
    @discardableResult
    private func seedApplication(
        in pipeline: PipelineStore,
        company: String = "Acme",
        status: ApplicationStatus = .applied,
        appliedAt: Date = now
    ) throws -> Application {
        let context = ModelContext(pipeline.container)
        let application = Application(
            company: company,
            roleTitle: "Senior Engineer",
            jobDescription: "JD",
            status: status,
            appliedAt: appliedAt
        )
        context.insert(application)
        try context.save()
        try pipeline.load()
        let seeded = pipeline.applications.first {
            $0.persistentModelID == application.persistentModelID
        }
        return try #require(seeded)
    }

    private func event(
        id: String = "evt-1",
        title: String,
        start: Date = now.addingTimeInterval(86_400),
        location: String? = nil,
        notes: String? = nil,
        attendees: [String] = [],
        organizerName: String? = nil,
        organizerEmail: String? = nil
    ) -> CalendarEvent {
        CalendarEvent(
            identifier: id,
            title: title,
            start: start,
            location: location,
            notes: notes,
            attendeeEmails: attendees,
            organizerName: organizerName,
            organizerEmail: organizerEmail
        )
    }

    // MARK: - Tracer

    @Test("[CALSYNC-1] a calendar event from a tracked company surfaces as a proposed Stage")
    func trackedCompanyEventBecomesProposal() async throws {
        let (pipeline, sync, _) = try makeStores(events: [event(title: "Acme interview")])
        let application = try seedApplication(in: pipeline, company: "Acme", status: .applied)

        await sync.scan(asOf: Self.now)

        #expect(sync.scanState == .ready)
        #expect(sync.proposals.count == 1)
        let proposal = try #require(sync.proposals.first)
        #expect(proposal.event.identifier == "evt-1")
        #expect(proposal.event.title == "Acme interview")
        #expect(proposal.event.start == Self.now.addingTimeInterval(86_400))
        #expect(proposal.candidates.map(\.persistentModelID) == [application.persistentModelID])
    }

    // MARK: - Scan-only guarantees

    @Test("[CALSYNC-2] a scan alone never creates a Stage")
    func scanCreatesNoStages() async throws {
        let (pipeline, sync, _) = try makeStores(events: [
            event(title: "Acme interview"),
            event(id: "evt-2", title: "Acme system design"),
        ])
        try seedApplication(in: pipeline)

        await sync.scan(asOf: Self.now)

        #expect(sync.proposals.count == 2)
        let stages = try ModelContext(pipeline.container).fetch(FetchDescriptor<Stage>())
        #expect(stages.isEmpty)
    }

    // MARK: - Matching

    @Test("[CALSYNC-4] an attendee email domain matching the company name proposes the event for that Application")
    func attendeeDomainProposesEvent() async throws {
        let (pipeline, sync, _) = try makeStores(events: [
            // Title never names the company; the attendee's registrable
            // domain does — jane@mail.acme.com → acme.
            event(title: "Interview", attendees: ["jane@mail.acme.com"]),
            // A public mail provider is never company evidence (the
            // decisions/0002 deny-list): live.com must not match "Live".
            event(id: "evt-2", title: "Sync call", attendees: ["bob@live.com"]),
        ])
        let acme = try seedApplication(in: pipeline, company: "Acme Corp")
        try seedApplication(in: pipeline, company: "Live", appliedAt: Self.now.addingTimeInterval(-3600))

        await sync.scan(asOf: Self.now)

        #expect(sync.proposals.count == 1)
        let proposal = try #require(sync.proposals.first)
        #expect(proposal.event.identifier == "evt-1")
        #expect(proposal.candidates.map(\.persistentModelID) == [acme.persistentModelID])
    }

    @Test("[CALSYNC-6] an event matching multiple Applications carries every match as a candidate on one proposal")
    func multiMatchYieldsOneProposalWithCandidates() async throws {
        let (pipeline, sync, _) = try makeStores(events: [event(title: "Acme final loop")])
        let older = try seedApplication(
            in: pipeline, company: "Acme", status: .applied,
            appliedAt: Self.now.addingTimeInterval(-86_400)
        )
        let newer = try seedApplication(
            in: pipeline, company: "Acme", status: .active, appliedAt: Self.now
        )

        await sync.scan(asOf: Self.now)

        #expect(sync.proposals.count == 1)
        let proposal = try #require(sync.proposals.first)
        // Board order (newest-first by applied date), never ranked.
        #expect(
            proposal.candidates.map(\.persistentModelID)
                == [newer.persistentModelID, older.persistentModelID]
        )
    }

    @Test("[CALSYNC-7] a recognised meeting link in the event becomes the proposal's meeting link")
    func meetingLinkDetection() async throws {
        let (pipeline, sync, _) = try makeStores(events: [
            event(id: "zoom", title: "Acme screen", location: "https://acme.zoom.us/j/123"),
            event(id: "teams", title: "Acme chat", notes: "Join: https://teams.microsoft.com/l/meetup/xyz"),
            event(
                id: "both", title: "Acme pairing",
                location: "https://meet.google.com/abc-defg-hij",
                notes: "Backup: https://acme.zoom.us/j/999"
            ),
            // A link that is not Zoom/Meet/Teams is not a meeting link; the
            // event is still proposed — enrichment, not a gate.
            event(id: "none", title: "Acme onsite", location: "Acme HQ", notes: "https://acme.com/directions"),
        ])
        try seedApplication(in: pipeline)

        await sync.scan(asOf: Self.now)

        let byID = Dictionary(uniqueKeysWithValues: sync.proposals.map { ($0.id, $0) })
        #expect(byID["zoom"]?.meetingLink == URL(string: "https://acme.zoom.us/j/123"))
        #expect(byID["teams"]?.meetingLink == URL(string: "https://teams.microsoft.com/l/meetup/xyz"))
        // Location outranks notes.
        #expect(byID["both"]?.meetingLink == URL(string: "https://meet.google.com/abc-defg-hij"))
        #expect(byID["none"] != nil)
        #expect(byID["none"]?.meetingLink == nil)
    }

    // MARK: - Confirmation

    @Test("[CALSYNC-8] confirming a proposal creates a pending Stage on the chosen Application")
    func confirmCreatesPendingStage() async throws {
        let start = Self.now.addingTimeInterval(86_400)
        let (pipeline, sync, _) = try makeStores(events: [
            event(title: "Acme screen", start: start, location: "https://acme.zoom.us/j/123")
        ])
        let application = try seedApplication(in: pipeline, status: .applied)
        await sync.scan(asOf: Self.now)
        let proposal = try #require(sync.proposals.first)

        let stage = try sync.confirm(proposal, application: application, kind: .screen)

        #expect(stage.kind == .screen)
        #expect(stage.outcome == .pending)
        #expect(stage.scheduledAt == start)
        #expect(stage.calendarEventID == "evt-1")
        #expect(stage.meetingURL == URL(string: "https://acme.zoom.us/j/123"))
        #expect(application.stages.count == 1)
        // Through PipelineStore.addStage, so the [PIPEBOARD-7] auto-advance
        // holds for calendar-born Stages too.
        #expect(application.status == .active)
        #expect(sync.proposals.isEmpty)
    }

    @Test("[CALSYNC-9] confirming a proposal against an existing Stage links the event to that Stage")
    func linkWritesCalendarFieldsOntoExistingStage() async throws {
        let start = Self.now.addingTimeInterval(86_400)
        let (pipeline, sync, _) = try makeStores(events: [
            event(title: "Acme technical", start: start, location: "https://meet.google.com/abc-defg-hij")
        ])
        let application = try seedApplication(in: pipeline, status: .active)
        let existing = try pipeline.addStage(to: application, kind: .technical)
        await sync.scan(asOf: Self.now)
        let proposal = try #require(sync.proposals.first)

        try sync.link(proposal, to: existing)

        let stages = try ModelContext(pipeline.container).fetch(FetchDescriptor<Stage>())
        #expect(stages.count == 1)
        let linked = try #require(stages.first)
        #expect(linked.calendarEventID == "evt-1")
        #expect(linked.meetingURL == URL(string: "https://meet.google.com/abc-defg-hij"))
        #expect(linked.scheduledAt == start)
        // Kind and outcome untouched.
        #expect(linked.kind == .technical)
        #expect(linked.outcome == .pending)
        #expect(sync.proposals.isEmpty)
    }

    // MARK: - Suppression

    @Test("[CALSYNC-10] an event already linked to a Stage is not proposed again")
    func linkedEventIsNotReproposed() async throws {
        let (pipeline, sync, _) = try makeStores(events: [
            event(title: "Acme screen"),
            event(id: "evt-2", title: "Acme final"),
        ])
        let application = try seedApplication(in: pipeline)
        await sync.scan(asOf: Self.now)
        let proposal = try #require(sync.proposals.first { $0.id == "evt-1" })
        try sync.confirm(proposal, application: application, kind: .screen)

        await sync.scan(asOf: Self.now)

        // The unlinked event at the same company keeps proposing.
        #expect(sync.proposals.map(\.id) == ["evt-2"])
    }

    @Test("[CALSYNC-11] a dismissed event is not proposed on later scans")
    func dismissedEventIsNotReproposed() async throws {
        let (pipeline, sync, _) = try makeStores(events: [
            event(title: "Acme screen"),
            event(id: "evt-2", title: "Acme final"),
        ])
        try seedApplication(in: pipeline)
        await sync.scan(asOf: Self.now)
        let proposal = try #require(sync.proposals.first { $0.id == "evt-1" })

        try sync.dismiss(proposal, asOf: Self.now)
        #expect(sync.proposals.map(\.id) == ["evt-2"])

        await sync.scan(asOf: Self.now)

        #expect(sync.proposals.map(\.id) == ["evt-2"])
    }

    // MARK: - Window and refresh

    @Test("[CALSYNC-13] the scan requests events from seven days back to thirty days ahead")
    func scanRequestsTheWindow() async throws {
        let (pipeline, sync, service) = try makeStores(events: [])
        try seedApplication(in: pipeline)

        await sync.scan(asOf: Self.now)

        let intervals = await service.requestedIntervals
        #expect(
            intervals == [
                DateInterval(
                    start: Self.now.addingTimeInterval(-7 * 86_400),
                    end: Self.now.addingTimeInterval(30 * 86_400)
                )
            ]
        )
    }

    @Test("[CALSYNC-14] a calendar change notification triggers a fresh scan")
    func changeNotificationTriggersScan() async throws {
        // The signal-triggered scan runs as of the real clock, so the
        // fixture event sits an hour ahead of it.
        let (pipeline, sync, _) = try makeStores(events: [
            event(title: "Acme interview", start: Date.now.addingTimeInterval(3_600))
        ])
        try seedApplication(in: pipeline)
        let center = NotificationCenter()
        sync.startObservingChanges(center: center)
        #expect(sync.proposals.isEmpty)

        center.post(name: .calendarSyncDidChange, object: nil)

        for _ in 0..<200 where sync.proposals.isEmpty {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(sync.proposals.map(\.id) == ["evt-1"])
    }

    // MARK: - Kind guess

    @Test("[CALSYNC-15] a kind keyword in the event title pre-selects the proposal's stage kind")
    func kindKeywordPreselects() async throws {
        // Multi-word kinds outrank single-word ones (decisions/0005):
        // "system design screen" guesses systemDesign, not screen.
        let (pipeline, sync, _) = try makeStores(events: [
            event(title: "Acme system design screen")
        ])
        try seedApplication(in: pipeline)

        await sync.scan(asOf: Self.now)

        #expect(sync.proposals.first?.kindGuess == .systemDesign)

        // The rest of the decisions/0005 map, straight through the helper.
        #expect(StageKindGuesser.guess(fromTitle: "Acme phone screen") == .screen)
        #expect(StageKindGuesser.guess(fromTitle: "Take-home review") == .takeHome)
        #expect(StageKindGuesser.guess(fromTitle: "Recruiter intro call") == .recruiter)
        #expect(StageKindGuesser.guess(fromTitle: "Pair programming with Acme") == .technical)
        #expect(StageKindGuesser.guess(fromTitle: "Values interview") == .behavioral)
        #expect(StageKindGuesser.guess(fromTitle: "Acme onsite") == .final)
        #expect(StageKindGuesser.guess(fromTitle: "Offer call") == .offer)
    }

    @Test("[CALSYNC-16] an event title with no kind keyword leaves the proposal's kind unselected")
    func noKeywordLeavesKindUnselected() async throws {
        let (pipeline, sync, _) = try makeStores(events: [event(title: "Acme catch-up")])
        try seedApplication(in: pipeline)

        await sync.scan(asOf: Self.now)

        let proposal = try #require(sync.proposals.first)
        #expect(proposal.kindGuess == nil)
        // Never a default kind, whatever the title.
        #expect(StageKindGuesser.guess(fromTitle: "Coffee with Jane") == nil)
    }

    // MARK: - Calendar-first: the interview heuristic (decisions/0007)

    @Test("[CALSYNC-21] an event matching no tracked Application whose title carries an interview keyword surfaces as a possible-interview proposal")
    func unmatchedKeywordEventBecomesPossibleInterview() async throws {
        // A tracked application exists — the event just names a company the
        // board has never heard of.
        let (pipeline, sync, _) = try makeStores(events: [
            event(title: "Interview with Hooli")
        ])
        try seedApplication(in: pipeline, company: "Acme")

        await sync.scan(asOf: Self.now)

        #expect(sync.scanState == .ready)
        #expect(sync.proposals.count == 1)
        let proposal = try #require(sync.proposals.first)
        #expect(proposal.event.identifier == "evt-1")
        // No candidates is what makes it a possible-interview proposal.
        #expect(proposal.candidates.isEmpty)

        // The heuristic runs even with an empty board — the calendar-first
        // arrival order (decisions/0007) — and the kind vocabulary counts
        // as interview keywords, so the kind guess rides along.
        let (_, sync2, _) = try makeStores(events: [
            event(title: "Hooli phone screen")
        ])
        await sync2.scan(asOf: Self.now)
        #expect(sync2.proposals.count == 1)
        #expect(sync2.proposals.first?.candidates.isEmpty == true)
        #expect(sync2.proposals.first?.kindGuess == .screen)
    }

    @Test("[CALSYNC-22] an event matching no tracked Application with a recognised meeting link surfaces as a possible-interview proposal")
    func unmatchedMeetingLinkEventBecomesPossibleInterview() async throws {
        // The title says nothing useful; the Zoom link is the signal.
        let (pipeline, sync, _) = try makeStores(events: [
            event(title: "Chat with Sarah", location: "https://hooli.zoom.us/j/9")
        ])
        try seedApplication(in: pipeline, company: "Acme")

        await sync.scan(asOf: Self.now)

        #expect(sync.proposals.count == 1)
        let proposal = try #require(sync.proposals.first)
        #expect(proposal.candidates.isEmpty)
        #expect(proposal.meetingLink == URL(string: "https://hooli.zoom.us/j/9"))
    }

    @Test("[CALSYNC-23] an event matching no tracked Application with neither an interview keyword nor a recognised meeting link yields no proposal")
    func unmatchedSilentEventYieldsNoProposal() async throws {
        let (pipeline, sync, _) = try makeStores(events: [
            event(title: "Dentist"),
            event(id: "evt-2", title: "Globex catch-up"),
            // A known company in a non-tracked status (decisions/0002) with
            // no heuristic signal stays invisible too.
            event(id: "evt-3", title: "Initech catch-up"),
            // Keyword containment is whole-word: "Sunscreen" never flags on
            // "screen".
            event(id: "evt-4", title: "Sunscreen shopping"),
            // A link that is not Zoom/Meet/Teams is not a meeting link.
            event(id: "evt-5", title: "Read the docs", notes: "https://globex.com/docs"),
        ])
        try seedApplication(in: pipeline, company: "Initech", status: .draft)

        await sync.scan(asOf: Self.now)

        #expect(sync.scanState == .ready)
        #expect(sync.proposals.isEmpty)
    }

    // MARK: - Calendar-first: the company guess and create-on-confirm

    @Test("[CALSYNC-24] the company guess takes the registrable-domain label of a non-public attendee or organizer email")
    func companyGuessFromEmailDomain() async throws {
        // Cased from the title when the label appears there as a word.
        let openCoreOS = event(
            title: "Interview with WayneTech",
            organizerEmail: "recruiting@waynetech.com"
        )
        #expect(CompanyGuesser.guess(for: openCoreOS) == "WayneTech")

        // No title occurrence → the label as-is; subdomains fall away the
        // [CALSYNC-4] way (mail.acme.com → acme).
        let acme = event(title: "Intro call", attendees: ["jane@mail.acme.com"])
        #expect(CompanyGuesser.guess(for: acme) == "acme")

        // The guess rides on the proposal for the sheet to pre-fill.
        let (_, sync, _) = try makeStores(events: [openCoreOS])
        await sync.scan(asOf: Self.now)
        #expect(sync.proposals.first?.companyGuess == "WayneTech")
    }

    @Test("[CALSYNC-25] with no usable email domain the company guess falls back to the event title stripped of interview vocabulary")
    func companyGuessFallsBackToStrippedTitle() async throws {
        // No emails at all — the no-email case.
        #expect(CompanyGuesser.guess(for: event(title: "Interview with Hooli")) == "Hooli")
        #expect(CompanyGuesser.guess(for: event(title: "Hooli phone screen")) == "Hooli")
        // Multi-word remainders keep their order and casing.
        #expect(
            CompanyGuesser.guess(for: event(title: "Final round at Wayne Enterprises"))
                == "Wayne Enterprises"
        )
        // A public mail domain is never company evidence — it falls through
        // to the title, the decisions/0002 deny-list again.
        #expect(
            CompanyGuesser.guess(
                for: event(title: "Interview with Hooli", attendees: ["me@gmail.com"])
            ) == "Hooli"
        )
        // Nothing left after stripping → empty; the sheet's field starts
        // blank and the user types.
        #expect(CompanyGuesser.guess(for: event(title: "Interview")).isEmpty)
    }

    @Test("[CALSYNC-26] confirming a possible-interview proposal creates an applied Application and its event-linked Stage")
    func confirmCreateCreatesApplicationAndStage() async throws {
        // A past interview — the calendar-first arrival order.
        let start = Self.now.addingTimeInterval(-86_400)
        let (pipeline, sync, _) = try makeStores(events: [
            event(title: "Interview with Hooli", start: start, location: "https://hooli.zoom.us/j/9"),
            event(id: "evt-2", title: "Globex interview"),
        ])
        await sync.scan(asOf: Self.now)
        let proposal = try #require(sync.proposals.first { $0.id == "evt-1" })
        #expect(proposal.candidates.isEmpty)

        let stage = try sync.confirmCreate(
            proposal, company: "Hooli", roleTitle: "Staff Engineer", kind: .screen
        )

        let application = try #require(stage.application)
        #expect(application.company == "Hooli")
        #expect(application.roleTitle == "Staff Engineer")
        #expect(application.source == "calendar")
        // Applied at the event's start — the best evidence on hand
        // (decisions/0007) — then auto-advanced to active by its first
        // Stage ([PIPEBOARD-7]).
        #expect(application.appliedAt == start)
        #expect(application.status == .active)
        #expect(stage.kind == .screen)
        #expect(stage.outcome == .pending)
        #expect(stage.scheduledAt == start)
        #expect(stage.calendarEventID == "evt-1")
        #expect(stage.meetingURL == URL(string: "https://hooli.zoom.us/j/9"))

        // A blank company refuses and creates nothing — the manual add's
        // invariant, reused.
        let second = try #require(sync.proposals.first { $0.id == "evt-2" })
        #expect(throws: PipelineStoreError.self) {
            try sync.confirmCreate(second, company: "   ", roleTitle: "X", kind: .screen)
        }
        #expect(pipeline.applications.count == 1)
        // The confirmed proposal left the list; the refused one stayed.
        #expect(sync.proposals.map(\.id) == ["evt-2"])
    }

    // MARK: - Calendar-first: the browse list and the look-back scan

    @Test("[CALSYNC-27] the browse list carries every event in the scan window except linked and dismissed ones")
    func browseListCarriesWindowEvents() async throws {
        let (pipeline, sync, _) = try makeStores(events: [
            event(title: "Acme interview"),
            event(id: "evt-2", title: "Dentist", start: Self.now.addingTimeInterval(2 * 86_400)),
            event(id: "evt-3", title: "Globex screen", start: Self.now.addingTimeInterval(3 * 86_400)),
            event(id: "evt-4", title: "Acme final", start: Self.now.addingTimeInterval(4 * 86_400)),
            event(id: "evt-5", title: "Acme screen", start: Self.now.addingTimeInterval(5 * 86_400)),
        ])
        let application = try seedApplication(in: pipeline)
        await sync.scan(asOf: Self.now)

        // Link one event's proposal, dismiss another — both leave the
        // browse list; matched, flagged, and plain events all stay, in
        // start order.
        let confirming = try #require(sync.proposals.first { $0.id == "evt-4" })
        try sync.confirm(confirming, application: application, kind: .final)
        let dismissing = try #require(sync.proposals.first { $0.id == "evt-5" })
        try sync.dismiss(dismissing, asOf: Self.now)

        #expect(sync.browseEvents.map(\.identifier) == ["evt-1", "evt-2", "evt-3"])
    }

    @Test("[CALSYNC-28] picking a browsed event yields a proposal for that event")
    func pickingBrowsedEventYieldsProposal() async throws {
        let (pipeline, sync, _) = try makeStores(events: [
            // Unmatched and heuristic-silent — invisible to the scan.
            event(title: "Coffee with Jane"),
            event(id: "evt-2", title: "Acme catch-up", start: Self.now.addingTimeInterval(2 * 86_400)),
        ])
        let application = try seedApplication(in: pipeline, company: "Acme")
        await sync.scan(asOf: Self.now)
        #expect(!sync.proposals.contains { $0.id == "evt-1" })

        // Picking proposes on demand, heuristic verdict ignored.
        let browsed = try #require(sync.browseEvents.first { $0.identifier == "evt-1" })
        let picked = sync.proposal(for: browsed)
        #expect(picked.isPossibleInterview)
        #expect(picked.companyGuess?.isEmpty == false)

        // A matched pick carries its candidates, [CALSYNC-6] semantics.
        let matchedEvent = try #require(sync.browseEvents.first { $0.identifier == "evt-2" })
        let matched = sync.proposal(for: matchedEvent)
        #expect(matched.candidates.map(\.persistentModelID) == [application.persistentModelID])
    }

    @Test("[CALSYNC-29] a look-back scan requests events from ninety days back to the scan instant")
    func lookBackRequestsNinetyDayWindow() async throws {
        let (pipeline, sync, service) = try makeStores(events: [])
        let application = try seedApplication(in: pipeline)

        await sync.lookBack(for: application, asOf: Self.now)

        let intervals = await service.requestedIntervals
        #expect(
            intervals == [
                DateInterval(
                    start: Self.now.addingTimeInterval(-90 * 86_400), end: Self.now
                )
            ]
        )
    }

    @Test("[CALSYNC-30] a look-back scan proposes only events matching its application's company")
    func lookBackProposesOnlyItsCompany() async throws {
        let (pipeline, sync, _) = try makeStores(events: [
            event(title: "Acme interview", start: Self.now.addingTimeInterval(-30 * 86_400)),
            // Another company's interview — heuristic-flaggable, and even
            // matched to a tracked application, but out of the look-back's
            // scope.
            event(id: "evt-2", title: "Globex interview", start: Self.now.addingTimeInterval(-30 * 86_400)),
            event(id: "evt-3", title: "Acme screen", start: Self.now.addingTimeInterval(-60 * 86_400)),
        ])
        let acme = try seedApplication(in: pipeline, company: "Acme")
        try seedApplication(in: pipeline, company: "Globex")

        await sync.lookBack(for: acme, asOf: Self.now)

        // Start order, sole candidate pinned to the invoked application.
        #expect(sync.proposals.map(\.id) == ["evt-3", "evt-1"])
        #expect(
            sync.proposals.allSatisfy {
                $0.candidates.map(\.persistentModelID) == [acme.persistentModelID]
            }
        )
    }

    // MARK: - Empty-scan explainers

    @Test("[CALSYNC-19] an empty scan with no tracked Application explains that matching starts past Draft")
    func emptyScanWithoutTrackedApplicationsSignalsCaseOne() async throws {
        // "Catch-up" carries no interview keyword and no meeting link, so
        // the heuristic stays silent too and the scan is genuinely empty.
        let (pipeline, sync, _) = try makeStores(events: [event(title: "Acme catch-up")])
        // A matching company still in Draft: matching never ran, and the
        // signal says why the scan came back empty.
        try seedApplication(in: pipeline, company: "Acme", status: .draft)

        await sync.scan(asOf: Self.now)

        #expect(sync.scanState == .ready)
        #expect(sync.proposals.isEmpty)
        #expect(sync.hasTrackedApplications == false)

        // Live, not captured at scan time (decisions/0006): tracking an
        // application after the scan flips the signal without a re-scan.
        try seedApplication(in: pipeline, company: "Globex", status: .applied)
        #expect(sync.hasTrackedApplications == true)
    }

    @Test("[CALSYNC-20] an empty scan with tracked Applications explains that no event matched")
    func emptyScanWithTrackedApplicationsSignalsCaseTwo() async throws {
        // A tracked Application whose company no event names — the
        // exact-match policy (decisions/0002) drops everything.
        let (pipeline, sync, _) = try makeStores(events: [event(title: "Globex catch-up")])
        try seedApplication(in: pipeline, company: "Acme", status: .applied)

        await sync.scan(asOf: Self.now)

        #expect(sync.scanState == .ready)
        #expect(sync.proposals.isEmpty)
        #expect(sync.hasTrackedApplications == true)
    }

    // MARK: - Denied access

    @Test("[CALSYNC-17] when calendar access is denied the scan reports the denied state")
    func deniedAccessReportsDeniedState() async throws {
        let (pipeline, sync, _) = try makeStores(
            events: [event(title: "Acme interview")], state: .denied
        )
        try seedApplication(in: pipeline)

        await sync.scan(asOf: Self.now)

        #expect(sync.scanState == .denied)
        #expect(sync.proposals.isEmpty)
        // The rest of the app is untouched — the board still has its data.
        #expect(pipeline.applications.count == 1)

        // Not-determined access whose request is refused lands in the same
        // state (decisions/0001: denied is a state, not an error).
        let (pipeline2, sync2, _) = try makeStores(
            events: [], state: .notDetermined, accessRequestResult: .denied
        )
        try seedApplication(in: pipeline2)
        await sync2.scan(asOf: Self.now)
        #expect(sync2.scanState == .denied)
    }
}

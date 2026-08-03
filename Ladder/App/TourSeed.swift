import Foundation
import SwiftData

/// The bundled fixtures' achievement ids, matched tags and grounding quotes
/// resolve against exactly this profile and these notes — reshaping the seed
/// breaks the tour's generation steps.
@MainActor
enum TourSeed {
    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-LadderTourSeed")
    }

    static var isBareRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-LadderTourBareSeed")
    }

    static let notesOverview = """
        ## Payments outage
        - Walked through the incident timeline and on-call rotation
        - Asked how the team measured recovery time

        ## CI pipeline
        - Discussed build times and flaky tests
        - Interviewer asked twice about Kubernetes experience
        """

    static func plant(in container: ModelContainer) throws {
        try plantProfile(in: container)
        try plantPipeline(in: container)
    }

    /// A separate seed rather than a variant of the one above, which cannot be
    /// reshaped without breaking the tour's generation steps. This one exists
    /// only so `TailorFlowStore.start()` refuses before it scans.
    static func plantBare(in container: ModelContainer) throws {
        let store = ProfileStore(container: container)
        try store.load()
        try store.createProfile(
            name: "Alex Climber", headline: "Staff Engineer — platform & reliability")
        try store.addRole(company: "Acme", title: "Senior Engineer", start: days(-1400), end: nil)

        let context = ModelContext(container)
        context.insert(
            Application(
                company: "Alpine Systems", roleTitle: "Staff iOS Engineer",
                jobDescription: """
                    Alpine Systems builds avalanche-forecasting tools used by mountain rescue \
                    teams. Swift, SwiftUI, GraphQL, team leadership.
                    """,
                status: .draft, createdAt: days(-2)))
        try context.save()
    }

    static func calendarEvents() -> [CalendarEvent] {
        [
            CalendarEvent(
                identifier: "tour-cairn-technical",
                title: "Cairn Health — systems interview",
                start: days(2, hour: 14),
                end: days(2, hour: 15),
                location: "https://cairn.zoom.us/j/8123",
                organizerName: "Rowan Diaz"
            ),
            CalendarEvent(
                identifier: "tour-summit-offer-call",
                title: "Summit Labs offer call",
                start: days(1, hour: 10),
                end: days(1, hour: 11),
                organizerName: "Jamie Ortiz"
            ),
        ]
    }

    private static func plantProfile(in container: ModelContainer) throws {
        let store = ProfileStore(container: container)
        try store.load()
        try store.createProfile(
            name: "Alex Climber", headline: "Staff Engineer — platform & reliability")
        try store.updateContact(
            ContactInfo(
                email: "alex@climber.dev", phone: "07700 900123",
                location: "Manchester, UK", link: "alexclimber.dev"))

        let acme = try store.addRole(
            company: "Acme", title: "Senior Engineer", start: days(-1400), end: nil)
        let ci = try store.addAchievement(
            to: acme, text: "Cut CI build times across every product target")
        try store.updateAchievementDetails(
            ci, impactMetric: "p95 build 38 min → 11 min", strengthNotes: nil)
        let sync = try store.addAchievement(to: acme, text: "Shipped the offline sync engine")
        let outage = try store.addAchievement(
            to: acme, text: "Led incident response for the payments outage")
        try store.updateAchievementDetails(
            outage, impactMetric: "42 min to full recovery",
            strengthNotes: "Ran incident command across three teams.")

        try store.tag(ci, skillNamed: "Swift")
        let kubernetes = try store.tag(ci, skillNamed: "Kubernetes")
        try store.recordAlias("k8s", on: kubernetes)
        try store.tag(sync, skillNamed: "SwiftUI")
        try store.tag(outage, skillNamed: "Leadership")

        let ridgeline = try store.addRole(
            company: "Ridgeline", title: "iOS Engineer", start: days(-2900), end: days(-1400))
        try store.addAchievement(
            to: ridgeline, text: "Took the field app offline-first for crews without signal")
        try store.addAchievement(
            to: ridgeline, text: "Halved cold-launch time on the oldest supported iPhones")

        try store.addEducation(
            institution: "University of Manchester",
            qualification: "BSc Computer Science",
            start: days(-6200), end: days(-5100))

        let trailhead = try store.addProject(
            name: "Trailhead",
            link: "github.com/alexclimber/trailhead",
            summary: "Route planning for hill days",
            details: "Offline maps and GPX overlays; used by two local walking groups.")
        try store.tag(trailhead, skillNamed: "SwiftUI")

        try store.addInterest("Hillwalking")
        try store.addInterest("Trail running")
        try store.addInterest("Film photography")
    }

    private static func plantPipeline(in container: ModelContainer) throws {
        let context = ModelContext(container)

        let alpine = Application(
            company: "Alpine Systems", roleTitle: "Staff iOS Engineer",
            jobDescription: """
                Alpine Systems builds avalanche-forecasting tools used by mountain rescue \
                teams. We're hiring a Staff iOS Engineer to own the field app end to end: \
                offline-first sync, SwiftUI at scale, and the GraphQL layer between app and \
                platform. You'll mentor a team of four and set the technical bar. Swift, \
                SwiftUI, GraphQL, team leadership; Kubernetes familiarity helps — the \
                backend runs on it.
                """,
            status: .draft, createdAt: days(-2))
        context.insert(alpine)

        let basecamp = Application(
            company: "Basecamp Robotics", roleTitle: "Senior Software Engineer",
            jobDescription: "Own the fleet-telemetry pipeline for warehouse robots.",
            status: .applied, source: "LinkedIn", appliedAt: days(-5), createdAt: days(-6))
        context.insert(basecamp)

        let cairn = Application(
            company: "Cairn Health", roleTitle: "Platform Engineer",
            jobDescription: "Keep the clinical records platform fast, safe, and boring.",
            status: .active, source: "Direct", appliedAt: days(-18), createdAt: days(-19))
        context.insert(cairn)
        let cairnScreen = Stage(
            kind: .screen, scheduledAt: days(-14), outcome: .passed,
            heardBackAt: days(-12), sortIndex: 0)
        context.insert(cairnScreen)
        cairnScreen.application = cairn
        let cairnTechnical = Stage(
            kind: .technical, scheduledAt: days(2, hour: 14),
            meetingURL: URL(string: "https://cairn.zoom.us/j/8123"),
            prepContext: "Systems design over video. They flagged the payments write-up — bring the incident timeline.",
            sortIndex: 1)
        context.insert(cairnTechnical)
        cairnTechnical.application = cairn

        let summit = Application(
            company: "Summit Labs", roleTitle: "Platform Engineer",
            jobDescription: """
                Own platform reliability across three product teams. You will lead incident \
                response, build paved-road tooling, and raise the reliability bar. \
                Kubernetes, CI at scale, incident response.
                """,
            status: .offer, source: "Referral — Jamie", appliedAt: days(-41), createdAt: days(-41),
            notes: "Team of five platform engineers. Reliability re-org under way — good timing.")
        context.insert(summit)

        let summitScreen = Stage(
            kind: .screen, scheduledAt: days(-38), outcome: .passed,
            heardBackAt: days(-36), sortIndex: 0)
        context.insert(summitScreen)
        summitScreen.application = summit
        let summitTechnical = Stage(
            kind: .technical, scheduledAt: days(-25),
            prepContext: "Expect systems questions. Lead with the payments outage.",
            outcome: .passed, heardBackAt: days(-22), sortIndex: 1)
        context.insert(summitTechnical)
        summitTechnical.application = summit
        let summitFinal = Stage(
            kind: .final, scheduledAt: days(-10), outcome: .passed,
            heardBackAt: days(-7), sortIndex: 2)
        context.insert(summitFinal)
        summitFinal.application = summit

        let transcript = Transcript(
            recordedAt: days(-25), durationSec: 3480, sourceApp: "Granola",
            notesSummary: notesOverview,
            segments: [
                Segment(
                    speaker: .them,
                    text: "Let's start with the payments outage — walk me through it.",
                    tStart: 62, tEnd: 70),
                Segment(
                    speaker: .me,
                    text: "Walked through the incident timeline and on-call rotation, then how we measured recovery.",
                    tStart: 71, tEnd: 190),
                Segment(
                    speaker: .them,
                    text: "How do you keep CI fast as the team grows?",
                    tStart: 480, tEnd: 486),
                Segment(
                    speaker: .me,
                    text: "Discussed build times and flaky tests — parallelising the suite cut the p95 build from 38 to 11 minutes.",
                    tStart: 487, tEnd: 610),
                Segment(
                    speaker: .them,
                    text: "And how deep does the Kubernetes experience go?",
                    tStart: 1180, tEnd: 1186),
            ])
        context.insert(transcript)
        summitTechnical.transcript = transcript

        let skills = (try context.fetch(FetchDescriptor<Profile>()).first?.skills) ?? []
        let matchedTags = ["Swift", "Kubernetes"].compactMap { name in
            skills.first { $0.name == name }
        }
        let match = Match(
            matchedTags: matchedTags,
            vocabularyGaps: ["GraphQL", "Team leadership"],
            scannedAt: days(-40))
        context.insert(match)
        summit.match = match

        let gully = Application(
            company: "Gully Analytics", roleTitle: "Data Platform Engineer",
            jobDescription: "Own the ingestion pipeline behind the analytics product.",
            status: .rejected, source: "Recruiter", appliedAt: days(-30), createdAt: days(-31))
        context.insert(gully)
        let gullyScreen = Stage(
            kind: .screen, scheduledAt: days(-26), outcome: .failed,
            heardBackAt: days(-21), sortIndex: 0)
        context.insert(gullyScreen)
        gullyScreen.application = gully

        let moraine = Application(
            company: "Moraine Software", roleTitle: "Engineering Manager",
            jobDescription: "Lead two product squads.",
            status: .withdrawn, appliedAt: days(-12), createdAt: days(-13),
            notes: "Withdrew — the role drifted from hands-on to pure people management.")
        context.insert(moraine)

        try context.save()
    }

    private static func days(_ offset: Int, hour: Int? = nil) -> Date {
        let date = Date.now.addingTimeInterval(Double(offset) * 86_400)
        guard let hour else { return date }
        return Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
    }
}

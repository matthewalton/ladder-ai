import Foundation
import PDFKit
import SwiftData
import Testing

@testable import Ladder

/// The shared preview fixture every `src/Preview/` test builds on.
///
/// Three roles newest-first — Acme (current; `a1` "Cut CI build times…",
/// `a2` "Shipped the offline sync engine"), Globex (ended; `a3` "Built the
/// reporting stack") and Initech, whose one achievement nothing selects, so
/// a bare role line is always in play and adding to it is testable. Two
/// projects, `p1` selected and `p2` not. The tailor result selects `a1`,
/// `a3` and `p1`.
///
/// Matched tags are CI/CD, Swift, SQL and Kubernetes; only `a2` carries
/// Kubernetes, so the seeded selection leaves exactly one matched tag
/// uncovered and adding `a2` closes it.
@MainActor
enum CVPreviewFixture {
    static let jobDescription =
        "Own platform reliability. Kubernetes, CI at scale, incident response."

    static let matchedTagNames = ["CI/CD", "Swift", "SQL", "Kubernetes"]

    /// `extraBullets` seeds unselected long achievements on the Acme role —
    /// the pool the preview's add surface reaches, and the way a test pushes
    /// an edited CV past two pages.
    static func profileStore(extraBullets: Int = 0) throws -> ProfileStore {
        let store = try ProfileStore(container: ProfileStore.container(inMemory: true))
        try store.load()
        try store.createProfile(name: "Alex Climber", headline: "Staff Engineer")
        let profile = try #require(store.profile)
        profile.contact = ContactInfo(
            email: "alex@example.com", phone: "+44 7700 900123",
            location: "London", link: "ladder.app/alex"
        )

        let acme = try store.addRole(
            company: "Acme", title: "Senior Engineer",
            start: Date(timeIntervalSince1970: 1_600_000_000), end: nil
        )
        let a1 = try store.addAchievement(
            to: acme, text: "Cut CI build times across every product target")
        let a2 = try store.addAchievement(to: acme, text: "Shipped the offline sync engine")
        let globex = try store.addRole(
            company: "Globex", title: "Engineer",
            start: Date(timeIntervalSince1970: 1_433_116_800),
            end: Date(timeIntervalSince1970: 1_517_443_200)
        )
        let a3 = try store.addAchievement(to: globex, text: "Built the reporting stack")
        let initech = try store.addRole(
            company: "Initech", title: "Junior Engineer",
            start: Date(timeIntervalSince1970: 1_357_000_000),
            end: Date(timeIntervalSince1970: 1_430_000_000)
        )
        try store.addAchievement(to: initech, text: "Automated the nightly release")
        for index in 0..<extraBullets {
            try store.addAchievement(
                to: acme,
                text: "Extra point \(index): delivered a measurable improvement to the platform, spelling out the constraint it removed, the teams it unblocked, and the metric it moved over the following two quarters"
            )
        }

        try store.tag(a1, skillNamed: "CI/CD")
        try store.tag(a1, skillNamed: "Swift")
        try store.tag(a2, skillNamed: "Kubernetes")
        try store.tag(a3, skillNamed: "SQL")

        let mapper = try store.addProject(
            name: "Trail Mapper", link: "github.com/alex/trail-mapper",
            details: "Engineered offline tile caching for a production mapping app."
        )
        try store.tag(mapper, skillNamed: "Swift")
        _ = try store.addProject(
            name: "Weather Widget", details: "Rendered live forecasts on the lock screen.")

        try store.addEducation(
            institution: "University of Example", qualification: "BSc Computer Science",
            start: Date(timeIntervalSince1970: 1_100_000_000),
            end: Date(timeIntervalSince1970: 1_200_000_000),
            detail: "First-class honours"
        )
        try store.addEducation(
            institution: "Open Courseware", qualification: "ML Specialisation",
            start: Date(timeIntervalSince1970: 1_450_000_000), end: nil
        )

        try store.addInterest("Cycling")
        try store.addInterest("Trail running")
        try store.addInterest("Coffee")
        return store
    }

    static func review(profileStore: ProfileStore) throws -> TailorReview {
        let profile = try #require(profileStore.profile)
        let acme = try #require(profile.roles.first(where: { $0.company == "Acme" }))
        let globex = try #require(profile.roles.first(where: { $0.company == "Globex" }))
        let a1 = acme.orderedAchievements[0]
        let a2 = acme.orderedAchievements[1]
        let a3 = try #require(globex.orderedAchievements.first)
        let mapper = try #require(profile.orderedProjects.first)
        let widget = profile.orderedProjects[1]

        let result = try makeTailorResult(
            json: """
            {
              "summary": "Senior engineer with platform-scale CI performance and analytics delivery behind them.",
              "selections": [
                {"achievementID": "a1", "bullet": "Drove CI build times down across every product target"},
                {"achievementID": "a3", "bullet": "Built the analytics reporting stack from scratch"}
              ],
              "projects": ["p1"],
              "skillCategories": [
                {"name": "Platform Engineering", "skills": ["CI/CD", "Swift"]},
                {"name": "Data", "skills": ["SQL"]}
              ],
              "relevance": {
                "a1": {"tech": 5, "domain": 4, "seniority": 3, "impact": 4},
                "a3": {"tech": 3, "domain": 4, "seniority": 3, "impact": 4},
                "p1": {"tech": 4, "domain": 5, "seniority": 2, "impact": 3}
              },
              "gaps": ["The JD asks for Kubernetes; nothing selected mentions it"],
              "rationale": "CI work maps directly to the JD's platform focus."
            }
            """,
            validAchievementIDs: ["a1", "a2", "a3"],
            validProjectIDs: ["p1", "p2"],
            tagNamesByID: [
                "a1": a1.skills.map(\.name),
                "a2": a2.skills.map(\.name),
                "a3": a3.skills.map(\.name),
                "p1": mapper.skills.map(\.name),
            ],
            matchedTagNames: matchedTagNames
        )
        return TailorReview(
            result: result,
            achievementsByID: ["a1": a1, "a2": a2, "a3": a3],
            projectsByID: ["p1": mapper, "p2": widget],
            matchedTagNames: matchedTagNames
        )
    }

    @discardableResult
    static func draft(
        in container: ModelContainer,
        status: ApplicationStatus = .draft,
        appliedAt: Date? = nil
    ) throws -> Application {
        let context = ModelContext(container)
        let application = Application(
            company: "Summit Labs", roleTitle: "Platform Engineer",
            jobDescription: jobDescription, status: status, appliedAt: appliedAt
        )
        context.insert(application)
        try context.save()
        return application
    }

    static func application(
        _ id: PersistentIdentifier, in container: ModelContainer
    ) throws -> Application {
        var descriptor = FetchDescriptor<Application>(
            predicate: #Predicate { $0.persistentModelID == id })
        descriptor.fetchLimit = 1
        return try #require(ModelContext(container).fetch(descriptor).first)
    }

    @MainActor
    struct Harness {
        let profileStore: ProfileStore
        let profile: Profile
        let review: TailorReview
        let applicationID: PersistentIdentifier
        let exportStore: CVExportStore
        let model: CVPreviewModel

        var container: ModelContainer { profileStore.container }
        var application: Application {
            get throws { try CVPreviewFixture.application(applicationID, in: container) }
        }
    }

    static func harness(
        extraBullets: Int = 0,
        rescorePass: RelevanceRescorePass? = nil,
        fitPasses: FitPassRunner? = nil
    ) async throws -> Harness {
        let profileStore = try profileStore(extraBullets: extraBullets)
        let profile = try #require(profileStore.profile)
        let review = try review(profileStore: profileStore)
        let application = try draft(in: profileStore.container)
        let exportStore = CVExportStore(container: profileStore.container)
        let composition = try await exportStore.compose(
            profile: profile, review: review, for: application.persistentModelID,
            fitPasses: fitPasses)
        return Harness(
            profileStore: profileStore,
            profile: profile,
            review: review,
            applicationID: application.persistentModelID,
            exportStore: exportStore,
            model: CVPreviewModel(
                profileStore: profileStore,
                profile: profile,
                review: review,
                applicationID: application.persistentModelID,
                jobDescription: jobDescription,
                composition: composition,
                rescorePass: rescorePass
            )
        )
    }

    static func achievement(
        _ text: String, in profileStore: ProfileStore
    ) throws -> Achievement {
        let profile = try #require(profileStore.profile)
        return try #require(
            profile.roles.flatMap(\.achievements).first(where: { $0.text == text }))
    }

    static func role(_ company: String, in profileStore: ProfileStore) throws -> Role {
        let profile = try #require(profileStore.profile)
        return try #require(profile.roles.first(where: { $0.company == company }))
    }

    static func project(_ name: String, in profileStore: ProfileStore) throws -> Project {
        let profile = try #require(profileStore.profile)
        return try #require(profile.projects.first(where: { $0.name == name }))
    }

    // MARK: - The oversized profile: a composition whose fit loop spends both passes

    static func oversizedProfileStore(bullets: Int = 100) throws -> ProfileStore {
        let store = try ProfileStore(container: ProfileStore.container(inMemory: true))
        try store.load()
        try store.createProfile(name: "Alex Climber", headline: "Staff Engineer")
        let acme = try store.addRole(
            company: "Acme", title: "Senior Engineer",
            start: Date(timeIntervalSince1970: 1_600_000_000), end: nil
        )
        for index in 1...bullets {
            try store.addAchievement(
                to: acme,
                text: "Achievement number \(index): delivered a measurable improvement to the platform, spelling out the constraint it removed, the teams it unblocked, and the metric it moved over the following two quarters"
            )
        }
        return store
    }

    static func oversizedReview(profileStore: ProfileStore) throws -> TailorReview {
        let profile = try #require(profileStore.profile)
        let acme = try #require(profile.roles.first)
        var byID: [String: Achievement] = [:]
        var selections: [String] = []
        var relevance: [String] = []
        for (index, achievement) in acme.orderedAchievements.enumerated() {
            let id = "a\(index + 1)"
            byID[id] = achievement
            selections.append(
                #"{"achievementID": "\#(id)", "bullet": "Rephrased achievement \#(index + 1) with sharper impact framing, spelling out the constraint it removed, the teams it unblocked, and the metric it moved over the following two quarters"}"#
            )
            relevance.append(#""\#(id)": {"tech": 3, "domain": 3, "seniority": 3, "impact": 3}"#)
        }
        let result = try makeTailorResult(
            json: """
            {
              "summary": "Everything-fits engineer.",
              "selections": [\(selections.joined(separator: ","))],
              "relevance": {\(relevance.joined(separator: ","))},
              "gaps": [],
              "rationale": "Everything fits."
            }
            """,
            validAchievementIDs: Set(byID.keys),
            matchedTagNames: []
        )
        return TailorReview(result: result, achievementsByID: byID)
    }

    /// A condense that barely shortens forces the terminal trim, so one
    /// composition spends both passes.
    static func bothPassesService(bullets: Int, keep: Int) -> FixtureIntelligenceService {
        let items = (0..<bullets).map { index in
            #"{"id": "b0-\#(index)", "text": "Delivered a measurable improvement, spelling out the constraint it removed, the teams it unblocked, and the metric it moved over the following two quarters of delivery \#(index)"}"#
        }
        let condensed = Data(#"{"items": [\#(items.joined(separator: ","))]}"#.utf8)
        let kept = (0..<keep).map { #""b0-\#($0)""# }.joined(separator: ",")
        return FixtureIntelligenceService(
            returning: [condensed, Data(#"{"keep": [\#(kept)]}"#.utf8)])
    }

    /// PDFKit breaks wrapped lines with newlines, so content assertions
    /// compare on whitespace-normalised text.
    static func extractedText(of pdfData: Data) throws -> String {
        let pdf = try #require(PDFDocument(data: pdfData), "the render produces a readable PDF")
        let raw = try #require(pdf.string, "the PDF carries an extractable text layer")
        return raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

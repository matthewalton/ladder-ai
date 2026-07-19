import Foundation
import PDFKit
import Testing

@testable import Ladder

/// Asserted by extracting text from the PDF with PDFKit — the extraction
/// succeeding at all is the ATS-parseable guarantee. Reviews are constructed
/// directly from a TailorResult; no service, no network.
@MainActor
struct CVRenderTests {
    /// Two roles, newest-first: Acme (current; "Cut CI…" = a1, "Shipped the
    /// offline sync engine" = a2) and Globex (ended; "Built the reporting
    /// stack" = a3). Ids follow the tailor payload's assignment order.
    private func makeProfileStore() throws -> ProfileStore {
        let store = try ProfileStore(container: ProfileStore.container(inMemory: true))
        try store.load()
        try store.createProfile(name: "Alex Climber", headline: "Staff Engineer")
        let profile = try #require(store.profile)
        profile.contact = ContactInfo(
            email: "alex@example.com", phone: "", location: "London", link: "ladder.app/alex"
        )
        let acme = try store.addRole(
            company: "Acme", title: "Senior Engineer",
            start: Date(timeIntervalSince1970: 1_600_000_000), end: nil  // Sep 2020 – Present
        )
        try store.addAchievement(to: acme, text: "Cut CI build times across every product target")
        try store.addAchievement(to: acme, text: "Shipped the offline sync engine")
        let globex = try store.addRole(
            company: "Globex", title: "Engineer",
            start: Date(timeIntervalSince1970: 1_433_116_800),  // Jun 2015
            end: Date(timeIntervalSince1970: 1_517_443_200)  // Feb 2018
        )
        try store.addAchievement(to: globex, text: "Built the reporting stack")
        return store
    }

    /// Selects a1 (Acme, rephrased) and a3 (Globex, rephrased); a2 stays
    /// outside the selection.
    @discardableResult
    private func makeReview(profileStore: ProfileStore) throws -> TailorReview {
        let profile = try #require(profileStore.profile)
        let acme = try #require(profile.roles.first(where: { $0.company == "Acme" }))
        let globex = try #require(profile.roles.first(where: { $0.company == "Globex" }))
        let a1 = acme.orderedAchievements[0]
        let a3 = try #require(globex.orderedAchievements.first)
        let result = try TailorResult(
            json: Data("""
            {
              "selections": [
                {"achievementID": "a1", "rephrasing": "Drove CI build times down across every product target"},
                {"achievementID": "a3", "rephrasing": "Built the analytics reporting stack from scratch"}
              ],
              "gaps": ["The JD asks for Kubernetes; nothing on file mentions it"],
              "rationale": "CI work maps directly to the JD's platform focus."
            }
            """.utf8),
            validAchievementIDs: ["a1", "a2", "a3"]
        )
        return TailorReview(result: result, achievementsByID: ["a1": a1, "a3": a3])
    }

    private func extractedText(profileStore: ProfileStore, review: TailorReview) throws -> String {
        let profile = try #require(profileStore.profile)
        let document = CVDocument(profile: profile, review: review)
        let pdfData = CVRenderer.pdfData(for: document)
        let pdf = try #require(PDFDocument(data: pdfData), "the render produces a readable PDF")
        return try #require(pdf.string, "the PDF carries an extractable text layer")
    }

    @Test("[CVEXPORT-2] the rendered CV contains the Profile's name, headline and contact details")
    func renderedCVContainsIdentityHeader() throws {
        let profileStore = try makeProfileStore()
        let review = try makeReview(profileStore: profileStore)

        let text = try extractedText(profileStore: profileStore, review: review)

        #expect(text.contains("Alex Climber"))
        #expect(text.contains("Staff Engineer"))
        #expect(text.contains("alex@example.com"))
        #expect(text.contains("London"))
        #expect(text.contains("ladder.app/alex"))
    }

    @Test("[CVEXPORT-3] the rendered CV lists every Role with its title, company and dates")
    func renderedCVListsEveryRoleWithDates() throws {
        let profileStore = try makeProfileStore()
        let review = try makeReview(profileStore: profileStore)

        let text = try extractedText(profileStore: profileStore, review: review)

        #expect(text.contains("Senior Engineer, Acme"))
        #expect(text.contains("Sep 2020 – Present"), "a current role renders its end as Present")
        #expect(text.contains("Engineer, Globex"))
        #expect(text.contains("Jun 2015 – Feb 2018"), "month-resolution dates")
        // Newest-first.
        let acme = try #require(text.range(of: "Senior Engineer, Acme"))
        let globex = try #require(text.range(of: "Engineer, Globex"))
        #expect(acme.lowerBound < globex.lowerBound)
    }

    @Test("[CVEXPORT-3] a Role with no selected achievements still appears in the rendered CV")
    func roleWithoutSelectionsStillAppears() throws {
        let profileStore = try makeProfileStore()
        // Select only a1 (Acme) — Globex contributes nothing.
        let profile = try #require(profileStore.profile)
        let acme = try #require(profile.roles.first(where: { $0.company == "Acme" }))
        let result = try TailorResult(
            json: Data("""
            {
              "selections": [
                {"achievementID": "a1", "rephrasing": "Drove CI build times down across every product target"}
              ],
              "gaps": [],
              "rationale": "CI focus."
            }
            """.utf8),
            validAchievementIDs: ["a1", "a2", "a3"]
        )
        let review = TailorReview(
            result: result, achievementsByID: ["a1": acme.orderedAchievements[0]]
        )

        let text = try extractedText(profileStore: profileStore, review: review)

        #expect(text.contains("Engineer, Globex"))
        #expect(text.contains("Jun 2015 – Feb 2018"))
    }

    @Test("[CVEXPORT-4] each selected achievement appears under its Role using the reviewed text")
    func selectedAchievementsAppearUnderTheirRoles() throws {
        let profileStore = try makeProfileStore()
        let review = try makeReview(profileStore: profileStore)

        let text = try extractedText(profileStore: profileStore, review: review)

        // Accepted rephrasings land between their role's header and the next.
        let acmeHeader = try #require(text.range(of: "Senior Engineer, Acme"))
        let acmeBullet = try #require(text.range(of: "Drove CI build times down across every product target"))
        let globexHeader = try #require(text.range(of: "Engineer, Globex"))
        let globexBullet = try #require(text.range(of: "Built the analytics reporting stack from scratch"))
        #expect(acmeHeader.lowerBound < acmeBullet.lowerBound)
        #expect(acmeBullet.lowerBound < globexHeader.lowerBound)
        #expect(globexHeader.lowerBound < globexBullet.lowerBound)
    }

    @Test("[CVEXPORT-4] a rejected rephrasing renders as the canonical text")
    func rejectedRephrasingRendersCanonicalText() throws {
        let profileStore = try makeProfileStore()
        let review = try makeReview(profileStore: profileStore)
        let globexItem = try #require(
            review.items.first(where: { $0.achievement.text == "Built the reporting stack" })
        )

        globexItem.accepted = false

        let text = try extractedText(profileStore: profileStore, review: review)
        #expect(text.contains("Built the reporting stack"))
        #expect(!text.contains("Built the analytics reporting stack from scratch"))
    }

    @Test("[CVEXPORT-5] an achievement outside the selection does not appear in the rendered CV")
    func nonSelectedAchievementIsAbsent() throws {
        let profileStore = try makeProfileStore()
        let review = try makeReview(profileStore: profileStore)

        let text = try extractedText(profileStore: profileStore, review: review)

        // a2's text appears nowhere else, so absence is assertable directly.
        #expect(!text.contains("Shipped the offline sync engine"))
    }

    @Test("[CVEXPORT-6] the rendered CV lists the Profile's skills")
    func renderedCVListsProfileSkills() throws {
        let profileStore = try makeProfileStore()
        let profile = try #require(profileStore.profile)
        let acme = try #require(profile.roles.first(where: { $0.company == "Acme" }))
        // Kubernetes tags an achievement outside the selection; skills are
        // Profile-level canon, so it appears anyway.
        try profileStore.tag(acme.orderedAchievements[0], skillNamed: "CI/CD")
        try profileStore.tag(acme.orderedAchievements[1], skillNamed: "Kubernetes")
        let review = try makeReview(profileStore: profileStore)

        let text = try extractedText(profileStore: profileStore, review: review)

        #expect(text.contains("Skills"))
        #expect(text.contains("CI/CD"))
        #expect(text.contains("Kubernetes"))
    }

    @Test("[CVEXPORT-7] every page of the rendered CV measures A4")
    func everyPageMeasuresA4() throws {
        let profileStore = try makeProfileStore()
        let review = try makeReview(profileStore: profileStore)
        let profile = try #require(profileStore.profile)

        let pdfData = CVRenderer.pdfData(for: CVDocument(profile: profile, review: review))

        let pdf = try #require(PDFDocument(data: pdfData))
        try #require(pdf.pageCount >= 1)
        for index in 0..<pdf.pageCount {
            let bounds = try #require(pdf.page(at: index)).bounds(for: .mediaBox)
            #expect(abs(bounds.width - 595.2) <= 1, "A4 width, ±1pt float rounding")
            #expect(abs(bounds.height - 841.8) <= 1, "A4 height, ±1pt float rounding")
        }
    }

    @Test("[CVEXPORT-7] a CV too long for one page paginates into A4 pages")
    func longCVPaginatesIntoA4Pages() throws {
        // Forty selected achievements overflow a single A4 page.
        let store = try ProfileStore(container: ProfileStore.container(inMemory: true))
        try store.load()
        try store.createProfile(name: "Alex Climber", headline: "Staff Engineer")
        let role = try store.addRole(
            company: "Acme", title: "Senior Engineer",
            start: Date(timeIntervalSince1970: 1_600_000_000), end: nil
        )
        var selections: [String] = []
        var byID: [String: Achievement] = [:]
        for index in 1...40 {
            let achievement = try store.addAchievement(
                to: role,
                text: "Achievement number \(index): delivered a measurable improvement to the platform"
            )
            byID["a\(index)"] = achievement
            selections.append(
                #"{"achievementID": "a\#(index)", "rephrasing": "Rephrased achievement \#(index) with sharper impact framing"}"#
            )
        }
        let result = try TailorResult(
            json: Data("""
            {
              "selections": [\(selections.joined(separator: ","))],
              "gaps": [],
              "rationale": "Everything fits."
            }
            """.utf8),
            validAchievementIDs: Set(byID.keys)
        )
        let review = TailorReview(result: result, achievementsByID: byID)
        let profile = try #require(store.profile)

        let pdfData = CVRenderer.pdfData(for: CVDocument(profile: profile, review: review))

        let pdf = try #require(PDFDocument(data: pdfData))
        #expect(pdf.pageCount > 1, "forty bullets cannot fit one A4 page")
        for index in 0..<pdf.pageCount {
            let bounds = try #require(pdf.page(at: index)).bounds(for: .mediaBox)
            #expect(abs(bounds.width - 595.2) <= 1)
            #expect(abs(bounds.height - 841.8) <= 1)
        }
        // The tail of the content survives pagination.
        let text = try #require(pdf.string)
        #expect(text.contains("Rephrased achievement 40"))
    }
}

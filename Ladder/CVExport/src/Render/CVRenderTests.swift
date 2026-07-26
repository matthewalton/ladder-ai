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
            start: Date(timeIntervalSince1970: 1_600_000_000), end: nil  // Sep 2020 - Present
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
              "summary": "Senior engineer with platform-scale CI performance and analytics delivery behind them.",
              "selections": [
                {"achievementID": "a1", "bullet": "Drove CI build times down across every product target"},
                {"achievementID": "a3", "bullet": "Built the analytics reporting stack from scratch"}
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

    @Test("[CVEXPORT-20] the rendered CV shows the reviewed outcome's summary under the identity header")
    func renderedCVShowsTheTailoredSummary() throws {
        let profileStore = try makeProfileStore()
        let review = try makeReview(profileStore: profileStore)

        // PDF extraction breaks wrapped lines with newlines, so compare on
        // whitespace-normalised text.
        let raw = try extractedText(profileStore: profileStore, review: review)
        let text = raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")

        let summary = "Senior engineer with platform-scale CI performance and analytics delivery behind them."
        #expect(text.contains(summary), "the summary renders verbatim")
        // Under the identity header, before the first role.
        let summaryIndex = try #require(text.range(of: summary)?.lowerBound)
        let nameIndex = try #require(text.range(of: "Alex Climber")?.lowerBound)
        let firstRoleIndex = try #require(text.range(of: "Senior Engineer, Acme")?.lowerBound)
        #expect(nameIndex < summaryIndex)
        #expect(summaryIndex < firstRoleIndex)
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
        #expect(text.contains("Sep 2020 - Present"), "a current role renders its end as Present")
        #expect(text.contains("Engineer, Globex"))
        #expect(text.contains("Jun 2015 - Feb 2018"), "month-resolution dates")
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
              "summary": "CI-focused engineer.",
              "selections": [
                {"achievementID": "a1", "bullet": "Drove CI build times down across every product target"}
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
        #expect(text.contains("Jun 2015 - Feb 2018"))
    }

    @Test("[CVEXPORT-31] a role's location and industry render on its subline")
    func roleSublineRendersLocationAndIndustry() throws {
        let profileStore = try makeProfileStore()
        let profile = try #require(profileStore.profile)
        let acme = try #require(profile.roles.first(where: { $0.company == "Acme" }))
        // Globex keeps nil for both — no subline at all, never an empty line.
        try profileStore.updateRole(
            acme, company: acme.company, title: acme.title, start: acme.start, end: acme.end,
            location: "London, UK", industry: "Fintech"
        )
        let review = try makeReview(profileStore: profileStore)

        let text = try extractedText(profileStore: profileStore, review: review)

        #expect(text.contains("London, UK · Fintech"), "both fields joined on the subline")
        // Between its role header and that role's first bullet.
        let header = try #require(text.range(of: "Senior Engineer, Acme"))
        let subline = try #require(text.range(of: "London, UK · Fintech"))
        let bullet = try #require(text.range(of: "Drove CI build times down"))
        #expect(header.lowerBound < subline.lowerBound)
        #expect(subline.lowerBound < bullet.lowerBound)
    }

    @Test("[CVEXPORT-31] a role with one print field renders that field alone")
    func roleSublineRendersLoneField() throws {
        let profileStore = try makeProfileStore()
        let profile = try #require(profileStore.profile)
        let globex = try #require(profile.roles.first(where: { $0.company == "Globex" }))
        try profileStore.updateRole(
            globex, company: globex.company, title: globex.title,
            start: globex.start, end: globex.end,
            location: nil, industry: "Analytics"
        )
        let review = try makeReview(profileStore: profileStore)

        let text = try extractedText(profileStore: profileStore, review: review)

        #expect(text.contains("Analytics"))
        #expect(!text.contains("· Analytics"), "no separator when one field is absent")
    }

    @Test("[CVEXPORT-32] a titled achievement's bullet opens with its title")
    func titledBulletOpensWithItsTitle() throws {
        let profileStore = try makeProfileStore()
        let profile = try #require(profileStore.profile)
        let acme = try #require(profile.roles.first(where: { $0.company == "Acme" }))
        // a1 gets a canonical title; a3 stays titleless and renders plain.
        try profileStore.updateAchievementTitle(
            acme.orderedAchievements[0], to: "Rebuilt the CI pipeline"
        )
        let review = try makeReview(profileStore: profileStore)

        let raw = try extractedText(profileStore: profileStore, review: review)
        let text = raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")

        #expect(
            text.contains("Rebuilt the CI pipeline - Drove CI build times down across every product target"),
            "the canonical title, the hyphen separator, then the reviewed text"
        )
        #expect(
            text.contains("• Built the analytics reporting stack from scratch"),
            "a titleless bullet renders the reviewed text alone, exactly as before"
        )
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

    @Test("[CVEXPORT-23] the rendered CV's skills section shows each named skill category with its skills")
    func renderedCVShowsSkillCategoriesWithTheirSkills() throws {
        let profileStore = try makeProfileStore()
        let profile = try #require(profileStore.profile)
        let acme = try #require(profile.roles.first(where: { $0.company == "Acme" }))
        let globex = try #require(profile.roles.first(where: { $0.company == "Globex" }))
        // CI/CD and Swift tag selected points; Kubernetes tags a2, outside
        // the selection — the decisions/0004 vocabulary bound survives the
        // grouping, so it must not appear.
        try profileStore.tag(acme.orderedAchievements[0], skillNamed: "CI/CD")
        try profileStore.tag(acme.orderedAchievements[0], skillNamed: "Swift")
        try profileStore.tag(acme.orderedAchievements[1], skillNamed: "Kubernetes")
        try profileStore.tag(try #require(globex.orderedAchievements.first), skillNamed: "SQL")

        let a1 = acme.orderedAchievements[0]
        let a3 = try #require(globex.orderedAchievements.first)
        let result = try TailorResult(
            json: Data("""
            {
              "summary": "Senior engineer with platform-scale CI performance behind them.",
              "selections": [
                {"achievementID": "a1", "bullet": "Drove CI build times down across every product target"},
                {"achievementID": "a3", "bullet": "Built the analytics reporting stack from scratch"}
              ],
              "skillCategories": [
                {"name": "Platform Engineering", "skills": ["CI/CD", "Swift"]},
                {"name": "Data", "skills": ["SQL"]}
              ],
              "gaps": [],
              "rationale": "CI work maps directly to the JD's platform focus."
            }
            """.utf8),
            validAchievementIDs: ["a1", "a2", "a3"],
            tagNamesByID: [
                "a1": a1.skills.map(\.name),
                "a3": a3.skills.map(\.name),
            ]
        )
        let review = TailorReview(result: result, achievementsByID: ["a1": a1, "a3": a3])

        let raw = try extractedText(profileStore: profileStore, review: review)
        let text = raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")

        #expect(text.contains("SKILLS"))
        #expect(
            text.contains("Platform Engineering: CI/CD, Swift"),
            "each category name appears with its skills"
        )
        #expect(text.contains("Data: SQL"))
        #expect(!text.contains("Kubernetes"), "a Tag on unselected content stays absent")
    }

    @Test("[CVEXPORT-18] the rendered CV lists every Education entry verbatim, newest-first")
    func renderedCVListsEducation() throws {
        let profileStore = try makeProfileStore()
        try profileStore.addEducation(
            institution: "University of Example", qualification: "BSc Computer Science",
            start: Date(timeIntervalSince1970: 1_100_000_000),  // Jan 2005
            end: Date(timeIntervalSince1970: 1_200_000_000),  // Jan 2008
            detail: "First-class honours"
        )
        try profileStore.addEducation(
            institution: "Open Courseware", qualification: "ML Specialisation",
            start: Date(timeIntervalSince1970: 1_450_000_000), end: nil  // Dec 2015 – Present
        )
        let review = try makeReview(profileStore: profileStore)

        let text = try extractedText(profileStore: profileStore, review: review)

        #expect(text.contains("EDUCATION"), "the template's tracked-caps section header")
        #expect(text.contains("BSc Computer Science, University of Example"))
        #expect(text.contains("First-class honours"))
        #expect(text.contains("ML Specialisation, Open Courseware"))
        // Newest-first: the in-progress specialisation precedes the degree.
        let course = try #require(text.range(of: "ML Specialisation, Open Courseware"))
        let degree = try #require(text.range(of: "BSc Computer Science, University of Example"))
        #expect(course.lowerBound < degree.lowerBound)
    }

    @Test("[CVEXPORT-21] a project appears on the rendered CV only when the selection includes it")
    func projectsRenderOnlyWhenSelected() throws {
        let profileStore = try makeProfileStore()
        let selectedProject = try profileStore.addProject(
            name: "Trail Mapper", link: "github.com/alex/trail-mapper",
            details: "Engineered offline tile caching for a production mapping app."
        )
        let unselectedProject = try profileStore.addProject(
            name: "Weather Widget", details: "Rendered live forecasts."
        )
        _ = unselectedProject

        let profile = try #require(profileStore.profile)
        let acme = try #require(profile.roles.first(where: { $0.company == "Acme" }))
        let result = try TailorResult(
            json: Data("""
            {
              "summary": "Platform and mapping engineer.",
              "selections": [
                {"achievementID": "a1", "bullet": "Drove CI build times down across every product target"}
              ],
              "projects": ["p1"],
              "gaps": [],
              "rationale": "Platform and mapping work both fit."
            }
            """.utf8),
            validAchievementIDs: ["a1", "a2", "a3"],
            validProjectIDs: ["p1", "p2"]
        )
        let review = TailorReview(
            result: result,
            achievementsByID: ["a1": acme.orderedAchievements[0]],
            projectsByID: ["p1": selectedProject]
        )

        let text = try extractedText(profileStore: profileStore, review: review)

        #expect(text.contains("PROJECTS"), "the template's tracked-caps section header")
        #expect(text.contains("Trail Mapper"))
        #expect(text.contains("github.com/alex/trail-mapper"))
        #expect(text.contains("Engineered offline tile caching for a production mapping app."),
                "the selected project's description renders verbatim")
        #expect(!text.contains("Weather Widget"), "an unselected project is absent")
        #expect(!text.contains("Rendered live forecasts."))
    }

    @Test("[CVEXPORT-34] the rendered CV embeds the template's bundled typefaces")
    func renderedCVEmbedsTemplateTypefaces() throws {
        let profileStore = try makeProfileStore()
        let review = try makeReview(profileStore: profileStore)
        let profile = try #require(profileStore.profile)

        let pdfData = CVRenderer.pdfData(for: CVDocument(profile: profile, review: review))

        let fonts = try #require(Self.embeddedFontNames(in: pdfData))
        #expect(fonts.contains { $0.contains("Inter") }, "body text is Inter — \(fonts)")
        #expect(
            fonts.contains { $0.contains("SourceSerif4-Bold") },
            "the name header is Source Serif 4 Bold — \(fonts)"
        )
        // The silent failure this guards: registration breaking and every
        // glyph falling back to the system font.
        #expect(
            !fonts.contains { $0.contains("SFPro") || $0.contains(".SF") || $0.contains("Helvetica") },
            "no system-font fallback for body text — \(fonts)"
        )
    }

    /// The `/BaseFont` names of every font resource in every page.
    private static func embeddedFontNames(in pdfData: Data) -> Set<String>? {
        guard
            let provider = CGDataProvider(data: pdfData as CFData),
            let document = CGPDFDocument(provider)
        else { return nil }
        var names: Set<String> = []
        for pageIndex in 1...document.numberOfPages {
            guard
                let dictionary = document.page(at: pageIndex)?.dictionary
            else { continue }
            var resources: CGPDFDictionaryRef?
            guard CGPDFDictionaryGetDictionary(dictionary, "Resources", &resources),
                  let resources else { continue }
            var fonts: CGPDFDictionaryRef?
            guard CGPDFDictionaryGetDictionary(resources, "Font", &fonts),
                  let fonts else { continue }
            CGPDFDictionaryApplyBlock(fonts, { _, value, _ in
                var font: CGPDFDictionaryRef?
                if CGPDFObjectGetValue(value, .dictionary, &font), let font {
                    var baseFont: UnsafePointer<CChar>?
                    if CGPDFDictionaryGetName(font, "BaseFont", &baseFont), let baseFont {
                        names.insert(String(cString: baseFont))
                    }
                }
                return true
            }, nil)
        }
        return names
    }

    @Test("[CVEXPORT-33] the rendered CV lists the Profile's interests in order")
    func renderedCVListsInterestsInOrder() throws {
        let profileStore = try makeProfileStore()
        try profileStore.addInterest("Cycling")
        try profileStore.addInterest("Trail running")
        try profileStore.addInterest("Coffee")
        let review = try makeReview(profileStore: profileStore)

        let text = try extractedText(profileStore: profileStore, review: review)

        #expect(text.contains("INTERESTS"))
        #expect(
            text.contains("Cycling · Trail running · Coffee"),
            "entry order preserved ([PROFILE-14])"
        )
    }

    @Test("[CVEXPORT-33] a Profile with no interests renders no Interests section")
    func noInterestsMeansNoInterestsSection() throws {
        let profileStore = try makeProfileStore()
        let review = try makeReview(profileStore: profileStore)

        let text = try extractedText(profileStore: profileStore, review: review)

        #expect(!text.contains("INTERESTS"), "an empty section is noise, the [CVEXPORT-21] stance")
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
                #"{"achievementID": "a\#(index)", "bullet": "Rephrased achievement \#(index) with sharper impact framing, spelling out the constraint it removed, the teams it unblocked, and the metric it moved over the following two quarters"}"#
            )
        }
        let result = try TailorResult(
            json: Data("""
            {
              "summary": "Everything-fits engineer.",
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

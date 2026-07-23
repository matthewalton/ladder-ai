import Foundation
import SwiftData
import Testing

@testable import Ladder

/// Each test simulates a relaunch by closing one container and reopening a
/// new one against the same store URL.
@MainActor
struct ProfilePersistenceTests {
    @Test("[PROFILE-1] a role added to the Profile is still present after the app relaunches")
    func roleSurvivesRelaunch() throws {
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }

        do {
            let store = try ProfileStore(container: ProfileStore.container(at: url))
            try store.load()
            try store.createProfile(name: "Alex Climber", headline: "Staff Engineer")
            try store.addRole(
                company: "Acme",
                title: "Senior Engineer",
                start: Date(timeIntervalSince1970: 1_600_000_000),
                end: nil
            )
        }

        let reopened = try ProfileStore(container: ProfileStore.container(at: url))
        try reopened.load()
        let profile = try #require(reopened.profile)
        #expect(profile.roles.count == 1)
        #expect(profile.roles.first?.company == "Acme")
        #expect(profile.roles.first?.title == "Senior Engineer")
    }

    @Test("[PROFILE-7] reordering a role's achievements persists the new order")
    func reorderedAchievementsKeepOrderAfterReopen() throws {
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }

        do {
            let store = try ProfileStore(container: ProfileStore.container(at: url))
            try store.load()
            try store.createProfile(name: "Alex Climber", headline: "")
            let role = try store.addRole(company: "Acme", title: "Engineer", start: .now, end: nil)
            try store.addAchievement(to: role, text: "First")
            try store.addAchievement(to: role, text: "Second")
            try store.addAchievement(to: role, text: "Third")

            // First moves to last; every intermediate index shifts by one.
            try store.moveAchievements(in: role, from: IndexSet(integer: 0), to: 3)
            #expect(role.orderedAchievements.map(\.text) == ["Second", "Third", "First"])
        }

        let reopened = try ProfileStore(container: ProfileStore.container(at: url))
        try reopened.load()
        let role = try #require(reopened.profile?.roles.first)
        #expect(role.orderedAchievements.map(\.text) == ["Second", "Third", "First"])
    }

    @Test("[PROFILE-9] editing an achievement's text persists the new text")
    func editedAchievementTextPersists() throws {
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }

        do {
            let store = try ProfileStore(container: ProfileStore.container(at: url))
            try store.load()
            try store.createProfile(name: "Alex Climber", headline: "")
            let role = try store.addRole(company: "Acme", title: "Engineer", start: .now, end: nil)
            let achievement = try store.addAchievement(to: role, text: "Gave the weak version")
            try store.updateAchievementText(achievement, to: "Held my ground on the caching trade-off")
            #expect(achievement.text == "Held my ground on the caching trade-off")
        }

        let reopened = try ProfileStore(container: ProfileStore.container(at: url))
        try reopened.load()
        let role = try #require(reopened.profile?.roles.first)
        #expect(role.orderedAchievements.first?.text == "Held my ground on the caching trade-off")
    }

    @Test("[PROFILE-5] a fully-populated Profile round-trips unchanged through a store reopen")
    func fullyPopulatedProfileRoundTrips() throws {
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }

        let updatedAt = Date(timeIntervalSince1970: 1_600_000_000)
        let currentStart = Date(timeIntervalSince1970: 1_500_000_000)
        let pastStart = Date(timeIntervalSince1970: 1_300_000_000)
        let pastEnd = Date(timeIntervalSince1970: 1_490_000_000)

        do {
            let container = try ProfileStore.container(at: url)
            let context = ModelContext(container)
            let profile = Profile(
                name: "Alex Climber",
                headline: "Staff Engineer",
                contact: ContactInfo(
                    email: "alex@example.com",
                    phone: "+44 7700 900123",
                    location: "London",
                    link: "https://alex.dev"
                ),
                updatedAt: updatedAt
            )
            context.insert(profile)

            let swift = SkillTag(name: "Swift")
            let swiftData = SkillTag(name: "SwiftData")
            profile.skills = [swift, swiftData]

            let current = Role(
                company: "Acme", title: "Senior Engineer", start: currentStart, end: nil,
                location: "London, UK", industry: "Fintech"
            )
            let past = Role(company: "Initech", title: "Engineer", start: pastStart, end: pastEnd)
            profile.roles = [current, past]

            let first = Achievement(
                text: "Cut CI build times across every product target",
                title: "Rebuilt the CI pipeline",
                impactMetric: "reduced build time 40%",
                tech: ["Swift", "Bazel"],
                strengthNotes: "Led the migration solo; strong STAR story",
                sortIndex: 0
            )
            let second = Achievement(
                text: "Shipped the offline sync engine",
                title: "Delivered offline sync",
                impactMetric: "0 data-loss reports in 12 months",
                tech: ["SwiftData", "CloudKit"],
                strengthNotes: "Good conflict-resolution war story",
                sortIndex: 1
            )
            current.achievements = [first, second]
            first.skills = [swift]
            second.skills = [swiftData]

            let degree = Education(
                institution: "University of Example",
                qualification: "BSc Computer Science",
                start: Date(timeIntervalSince1970: 1_100_000_000),
                end: Date(timeIntervalSince1970: 1_200_000_000),
                detail: "First-class honours"
            )
            let course = Education(
                institution: "Open Courseware",
                qualification: "ML Specialisation",
                start: Date(timeIntervalSince1970: 1_450_000_000),
                end: nil,
                detail: ""
            )
            profile.education = [degree, course]

            let project = Project(
                name: "Trail Mapper",
                link: "https://github.com/alex/trail-mapper",
                summary: "Offline-first hiking maps",
                details: "Built tile caching so a week's maps survive without signal.",
                sortIndex: 0
            )
            profile.projects = [project]
            project.skills = [swift]

            profile.interests = ["climbing", "trail running", "coffee"]

            try context.save()
        }

        let container = try ProfileStore.container(at: url)
        let context = ModelContext(container)
        let profile = try #require(try context.fetch(FetchDescriptor<Profile>()).first)

        #expect(profile.name == "Alex Climber")
        #expect(profile.headline == "Staff Engineer")
        #expect(profile.contact.email == "alex@example.com")
        #expect(profile.contact.phone == "+44 7700 900123")
        #expect(profile.contact.location == "London")
        #expect(profile.contact.link == "https://alex.dev")
        #expect(profile.updatedAt == updatedAt)
        #expect(Set(profile.skills.map(\.name)) == ["Swift", "SwiftData"])

        #expect(profile.roles.count == 2)
        let current = try #require(profile.roles.first { $0.company == "Acme" })
        let past = try #require(profile.roles.first { $0.company == "Initech" })
        #expect(current.title == "Senior Engineer")
        #expect(current.start == currentStart)
        #expect(current.end == nil, "a current role has a nil end")
        #expect(current.location == "London, UK")
        #expect(current.industry == "Fintech")
        #expect(past.title == "Engineer")
        #expect(past.start == pastStart)
        #expect(past.end == pastEnd)
        #expect(past.location == nil, "print fields are optional — absent stays nil (decisions/0010)")
        #expect(past.industry == nil)

        let achievements = current.orderedAchievements
        #expect(achievements.count == 2)
        let first = try #require(achievements.first)
        #expect(first.text == "Cut CI build times across every product target")
        #expect(first.title == "Rebuilt the CI pipeline")
        #expect(first.impactMetric == "reduced build time 40%")
        #expect(first.tech == ["Swift", "Bazel"])
        #expect(first.strengthNotes == "Led the migration solo; strong STAR story")
        #expect(first.skills.map(\.name) == ["Swift"])
        let second = try #require(achievements.last)
        #expect(second.text == "Shipped the offline sync engine")
        #expect(second.title == "Delivered offline sync")
        #expect(second.impactMetric == "0 data-loss reports in 12 months")
        #expect(second.tech == ["SwiftData", "CloudKit"])
        #expect(second.strengthNotes == "Good conflict-resolution war story")
        #expect(second.skills.map(\.name) == ["SwiftData"])

        #expect(profile.education.count == 2)
        let degree = try #require(profile.education.first { $0.institution == "University of Example" })
        #expect(degree.qualification == "BSc Computer Science")
        #expect(degree.start == Date(timeIntervalSince1970: 1_100_000_000))
        #expect(degree.end == Date(timeIntervalSince1970: 1_200_000_000))
        #expect(degree.detail == "First-class honours")
        let course = try #require(profile.education.first { $0.institution == "Open Courseware" })
        #expect(course.end == nil, "in-progress education has a nil end")
        #expect(course.detail == "")

        let project = try #require(profile.projects.first)
        #expect(project.name == "Trail Mapper")
        #expect(project.link == "https://github.com/alex/trail-mapper")
        #expect(project.summary == "Offline-first hiking maps")
        #expect(project.details == "Built tile caching so a week's maps survive without signal.")
        #expect(project.skills.map(\.name) == ["Swift"], "project Tags share the profile's pool")

        #expect(profile.interests == ["climbing", "trail running", "coffee"], "interests keep entered order")
    }

    @Test("[PROFILE-13] identity and contact edits are still there after the app relaunches")
    func identityAndContactEditsSurviveRelaunch() throws {
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }

        let contact = ContactInfo(
            email: "alex@example.com", phone: "+44 7700 900123", location: "London", link: "https://alex.dev"
        )
        do {
            let store = try ProfileStore(container: ProfileStore.container(at: url))
            try store.load()
            try store.createProfile(name: "Alex Climber", headline: "Engineer")
            try store.updateIdentity(name: "Alexandra Climber", headline: "Staff Engineer")
            try store.updateContact(contact)
        }

        let reopened = try ProfileStore(container: ProfileStore.container(at: url))
        try reopened.load()
        let profile = try #require(reopened.profile)
        #expect(profile.name == "Alexandra Climber")
        #expect(profile.headline == "Staff Engineer")
        #expect(profile.contact == contact)
    }

    @Test("[PROFILE-17] replacing the Profile's content leaves exactly the replacement content after a store reopen")
    func replaceLeavesOnlyReplacementContent() throws {
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }

        let beforeReplace = Date.now

        do {
            let store = try ProfileStore(container: ProfileStore.container(at: url))
            try store.load()
            try store.createProfile(name: "Old Name", headline: "Old headline")
            try store.updateContact(ContactInfo(
                email: "old@example.com", phone: "000", location: "Old Town", link: "https://old.example"
            ))
            let role = try store.addRole(
                company: "OldCo", title: "Old Engineer",
                start: Date(timeIntervalSince1970: 1_000_000_000), end: nil
            )
            let achievement = try store.addAchievement(to: role, text: "Old achievement")
            try store.tag(achievement, skillNamed: "OldSkill")
            try store.addEducation(
                institution: "Old University", qualification: "Old BSc",
                start: Date(timeIntervalSince1970: 900_000_000), end: nil
            )
            let project = try store.addProject(name: "Old Project")
            try store.tag(project, skillNamed: "OldProjectSkill")
            try store.addInterest("Old interest")

            let replacement = ProfileReplacement(
                name: "Matthew Alton",
                headline: "Software Engineer",
                contact: ContactInfo(
                    email: "matt@example.com", phone: "07541 000000",
                    location: "London, UK", link: "https://matt.dev"
                ),
                roles: [ReplacementRole(
                    company: "Travelex", title: "Software Engineer",
                    start: Date(timeIntervalSince1970: 1_700_000_000), end: nil,
                    location: "  London, UK  ",  // lands trimmed (decisions/0010)
                    industry: "   ",  // empty after trimming lands as nil
                    achievements: [
                        ReplacementPoint(
                            title: "Shipped Rate Sale",
                            text: "Shipped the Rate Sale feature",
                            impactMetric: "5 minutes, down from 2 hours",
                            tech: ["React", "TypeScript"],
                            // Dedupes to one Tag by the [PROFILE-8] rule.
                            skills: ["React", " react "]
                        ),
                        ReplacementPoint(text: "Won the AI Olympiad", skills: ["Agentic workflows"]),
                    ]
                )],
                education: [ReplacementEducation(
                    institution: "University of Newcastle",
                    qualification: "BSc Computer Science",
                    start: Date(timeIntervalSince1970: 1_150_000_000),
                    end: Date(timeIntervalSince1970: 1_300_000_000),
                    detail: "1st Class Honours"
                )],
                projects: [ReplacementProject(
                    name: "Baton",
                    link: "https://github.com/matthewalton/baton",
                    summary: "Native macOS kanban board",
                    details: "A SwiftUI kanban app with an MCP server embedded in the app itself.",
                    // " react " joins the achievements' "React" — one shared
                    // Tag ([PROFILE-21]); "SQLite" is project-only.
                    skills: [" react ", "SQLite"]
                )],
                interests: ["Cycling", "Running", " cycling "]
            )
            try store.replaceProfile(with: replacement)
        }

        let reopened = try ProfileStore(container: ProfileStore.container(at: url))
        try reopened.load()
        let profile = try #require(reopened.profile)

        #expect(profile.name == "Matthew Alton")
        #expect(profile.headline == "Software Engineer")
        #expect(profile.contact.email == "matt@example.com")
        #expect(profile.contact.phone == "07541 000000")
        #expect(profile.contact.location == "London, UK")
        #expect(profile.contact.link == "https://matt.dev")
        #expect(profile.updatedAt >= beforeReplace, "updatedAt is set at replace time")

        let role = try #require(profile.roles.first)
        #expect(profile.roles.count == 1)
        #expect(role.company == "Travelex")
        #expect(role.location == "London, UK", "replacement print fields land trimmed (decisions/0010)")
        #expect(role.industry == nil, "empty after trimming lands as nil")
        #expect(role.orderedAchievements.map(\.text) == [
            "Shipped the Rate Sale feature", "Won the AI Olympiad",
        ])
        let first = try #require(role.orderedAchievements.first)
        #expect(first.title == "Shipped Rate Sale")
        #expect(first.impactMetric == "5 minutes, down from 2 hours")
        #expect(role.orderedAchievements.last?.title == nil, "a point without a lead-in stays titleless")
        #expect(first.tech == ["React", "TypeScript"])
        #expect(first.skills.map(\.name) == ["React"], "skill names dedupe per [PROFILE-8]")

        let education = try #require(profile.education.first)
        #expect(profile.education.count == 1)
        #expect(education.institution == "University of Newcastle")
        #expect(education.detail == "1st Class Honours")

        let project = try #require(profile.projects.first)
        #expect(profile.projects.count == 1)
        #expect(project.name == "Baton")
        #expect(project.details == "A SwiftUI kanban app with an MCP server embedded in the app itself.")
        #expect(
            Set(project.skills.map(\.name)) == ["React", "SQLite"],
            "project skills join the shared pool, deduped per [PROFILE-8]"
        )

        #expect(profile.interests == ["Cycling", "Running"], "interests dedupe per [PROFILE-14]")

        // All-or-nothing: nothing of the old content survives anywhere in the
        // store — the Tag pool is rebuilt from the replacement alone.
        let context = ModelContext(reopened.container)
        #expect(try context.fetchCount(FetchDescriptor<Profile>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Role>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Achievement>()) == 2)
        #expect(try context.fetchCount(FetchDescriptor<Education>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Project>()) == 1)
        let tags = try context.fetch(FetchDescriptor<SkillTag>())
        #expect(Set(tags.map(\.name)) == ["React", "Agentic workflows", "SQLite"])
    }

    @Test("[PROFILE-22] editing a role's location and industry persists across a store reopen")
    func roleLocationAndIndustryEditsSurviveReopen() throws {
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }

        let start = Date(timeIntervalSince1970: 1_600_000_000)
        do {
            let store = try ProfileStore(container: ProfileStore.container(at: url))
            try store.load()
            try store.createProfile(name: "Alex Climber", headline: "")
            let filled = try store.addRole(company: "Acme", title: "Engineer", start: start, end: nil)
            #expect(filled.location == nil, "print fields start absent — manual backfill (decisions/0010)")
            #expect(filled.industry == nil)
            try store.updateRole(
                filled, company: "Acme", title: "Engineer", start: start, end: nil,
                location: "  London, UK  ", industry: "Fintech"
            )
            let blanked = try store.addRole(company: "Initech", title: "Engineer", start: start, end: nil)
            try store.updateRole(
                blanked, company: "Initech", title: "Engineer", start: start, end: nil,
                location: "   ", industry: ""
            )
        }

        let reopened = try ProfileStore(container: ProfileStore.container(at: url))
        try reopened.load()
        let profile = try #require(reopened.profile)
        let filled = try #require(profile.roles.first { $0.company == "Acme" })
        #expect(filled.location == "London, UK", "stored trimmed")
        #expect(filled.industry == "Fintech")
        let blanked = try #require(profile.roles.first { $0.company == "Initech" })
        #expect(blanked.location == nil, "empty after trimming persists as nil, never an empty string")
        #expect(blanked.industry == nil)
    }

    @Test("[PROFILE-23] editing a point's title persists the new title")
    func achievementTitleEditSurvivesReopen() throws {
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }

        do {
            let store = try ProfileStore(container: ProfileStore.container(at: url))
            try store.load()
            try store.createProfile(name: "Alex Climber", headline: "")
            let role = try store.addRole(company: "Acme", title: "Engineer", start: .now, end: nil)
            let titled = try store.addAchievement(to: role, text: "cut deploy time 80%")
            #expect(titled.title == nil, "titles start absent — manual backfill (decisions/0010)")
            try store.updateAchievementTitle(titled, to: "  Shipped the pipeline  ")
            #expect(titled.title == "Shipped the pipeline", "stored trimmed")

            let blanked = try store.addAchievement(to: role, text: "kept the lights on")
            try store.updateAchievementTitle(blanked, to: "Temporary")
            try store.updateAchievementTitle(blanked, to: "   ")
            #expect(blanked.title == nil, "empty after trimming persists as nil")
        }

        let reopened = try ProfileStore(container: ProfileStore.container(at: url))
        try reopened.load()
        let role = try #require(reopened.profile?.roles.first)
        let points = role.orderedAchievements
        #expect(points.first?.title == "Shipped the pipeline")
        #expect(points.first?.text == "cut deploy time 80%", "the title never displaces the description")
        #expect(points.last?.title == nil)
    }

    @Test("[PROFILE-15] deleting a point persists, with the surviving siblings' order intact")
    func deletedPointStaysGoneAfterReopen() throws {
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }

        do {
            let store = try ProfileStore(container: ProfileStore.container(at: url))
            try store.load()
            try store.createProfile(name: "Alex Climber", headline: "")
            let role = try store.addRole(company: "Acme", title: "Engineer", start: .now, end: nil)
            try store.addAchievement(to: role, text: "First")
            let second = try store.addAchievement(to: role, text: "Second")
            try store.addAchievement(to: role, text: "Third")
            try store.deleteAchievement(second)
        }

        let reopened = try ProfileStore(container: ProfileStore.container(at: url))
        try reopened.load()
        let role = try #require(reopened.profile?.roles.first)
        #expect(role.orderedAchievements.map(\.text) == ["First", "Third"])
    }

    @Test("[PROFILE-20] editing a Project's description persists the new text")
    func projectDescriptionEditSurvivesReopen() throws {
        let url = temporaryStoreURL()
        defer { removeStore(at: url) }

        do {
            let store = try ProfileStore(container: ProfileStore.container(at: url))
            try store.load()
            try store.createProfile(name: "Alex Climber", headline: "")
            let project = try store.addProject(name: "Trail Mapper")
            try store.updateProject(
                project,
                name: "Trail Mapper",
                link: "https://example.com",
                summary: "Offline-first hiking maps",
                details: "Built tile caching so a week's maps survive without signal."
            )
        }

        let reopened = try ProfileStore(container: ProfileStore.container(at: url))
        try reopened.load()
        let project = try #require(reopened.profile?.projects.first)
        #expect(project.details == "Built tile caching so a week's maps survive without signal.")
        #expect(project.summary == "Offline-first hiking maps")
        #expect(project.link == "https://example.com")
    }
}

// MARK: - Helpers shared by this slice's tests

@MainActor
func temporaryStoreURL() -> URL {
    URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("ladder-profile-tests-\(UUID().uuidString).store")
}

@MainActor
func removeStore(at url: URL) {
    let fm = FileManager.default
    for suffix in ["", "-shm", "-wal"] {
        try? fm.removeItem(at: URL(fileURLWithPath: url.path + suffix))
    }
}

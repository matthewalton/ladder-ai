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

            let current = Role(company: "Acme", title: "Senior Engineer", start: currentStart, end: nil)
            let past = Role(company: "Initech", title: "Engineer", start: pastStart, end: pastEnd)
            profile.roles = [current, past]

            let first = Achievement(
                text: "Cut CI build times across every product target",
                impactMetric: "reduced build time 40%",
                tech: ["Swift", "Bazel"],
                strengthNotes: "Led the migration solo; strong STAR story",
                sortIndex: 0
            )
            let second = Achievement(
                text: "Shipped the offline sync engine",
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
                sortIndex: 0
            )
            profile.projects = [project]
            let point = Achievement(text: "Built tile caching for offline use", sortIndex: 0)
            project.points = [point]
            point.skills = [swift]

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
        #expect(past.title == "Engineer")
        #expect(past.start == pastStart)
        #expect(past.end == pastEnd)

        let achievements = current.orderedAchievements
        #expect(achievements.count == 2)
        let first = try #require(achievements.first)
        #expect(first.text == "Cut CI build times across every product target")
        #expect(first.impactMetric == "reduced build time 40%")
        #expect(first.tech == ["Swift", "Bazel"])
        #expect(first.strengthNotes == "Led the migration solo; strong STAR story")
        #expect(first.skills.map(\.name) == ["Swift"])
        let second = try #require(achievements.last)
        #expect(second.text == "Shipped the offline sync engine")
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
        let point = try #require(project.orderedPoints.first)
        #expect(point.text == "Built tile caching for offline use")
        #expect(point.role == nil, "a project point has no role")
        #expect(point.skills.map(\.name) == ["Swift"], "project points share the profile's Tags")

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
